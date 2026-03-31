import BasicContainers

final class MountContainer {
    private let viewContext: _ViewContext
    private var activeSlots: UniqueArray<Slot>
    private var leavingSlots: UniqueArray<Slot> = .init()
    private var removedNodes: UniqueArray<RemovedNode> = .init()

    var containerHandle: LayoutContainer.Handle?

    private var keyedDiff: KeyedDiffEngine = .init()
    private var removedMiddleSlots: UniqueArray<Slot> = .init()
    private var leavingRemovalScratch: UniqueArray<Int> = .init()

    private var pendingMakeNode: ((Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable)?

    private init(context: borrowing _ViewContext, slots: consuming UniqueArray<Slot>) {
        self.viewContext = copy context
        self.activeSlots = slots
    }

    convenience init<Node: _Reconcilable>(
        mountedKey key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.init(
            context: context,
            slots: UniqueArray<Slot>(capacity: 1) { span in
                let mountedSlot = ctx.withMountRootContext { (rootCtx: consuming _MountContext) in
                    Slot.mounted(
                        key: key,
                        mounted: rootCtx.makeMountedState(
                            newKeyIndex: 0,
                            viewContext: context,
                            makeNode: { _, viewContext, mountCtx in
                                AnyReconcilable(makeNode(viewContext, &mountCtx))
                            }
                        )
                    )
                }
                span.append(mountedSlot)
            }
        )
    }

    convenience init<Node: _Reconcilable>(
        mountedKeyStorage keys: borrowing Span<_ViewKey>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.init(
            context: context,
            slots: UniqueArray<Slot>(capacity: keys.count) { span in
                for index in keys.indices {
                    let mountedSlot = ctx.withMountRootContext { (rootCtx: consuming _MountContext) in
                        Slot.mounted(
                            key: keys[unchecked: index],
                            mounted: rootCtx.makeMountedState(
                                newKeyIndex: index,
                                viewContext: context,
                                makeNode: { index, viewContext, mountCtx in
                                    AnyReconcilable(makeNode(index, viewContext, &mountCtx))
                                }
                            )
                        )
                    }
                    span.append(mountedSlot)
                }
            }
        )
    }

    func collect(into ops: inout LayoutPass, context: inout _CommitContext, op: LayoutPass.Entry.LayoutOp) {
        if containerHandle == nil { containerHandle = ops.containerHandle }

        promoteReadyLeavingNodes()

        while var removed = removedNodes.popLast() {
            removed.collectRemoved(into: &ops, context: &context)
        }

        for index in activeSlots.indices {
            activeSlots[index].collectActive(
                into: &ops,
                context: &context,
                viewContext: viewContext,
                makeNode: pendingMakeNode,
                parentOp: op
            )
        }

        pendingMakeNode = nil
    }

    func unmount(_ context: inout _CommitContext) {
        for index in activeSlots.indices {
            activeSlots[index].unmount(&context)
        }
        for index in leavingSlots.indices {
            leavingSlots[index].unmount(&context)
        }
        while var removed = removedNodes.popLast() {
            removed.unmount(&context)
        }

        activeSlots.removeAll(keepingCapacity: true)
        leavingSlots.removeAll(keepingCapacity: true)
        removedNodes.removeAll(keepingCapacity: true)
        containerHandle = nil
    }

    func reportLayoutChange(_ tx: inout _TransactionContext) {
        containerHandle?.reportLayoutChange(&tx)
    }

    func patch(
        keys newKeys: borrowing Span<_ViewKey>,
        tx: inout _TransactionContext,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (Int, AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        pendingMakeNode = makeNode
        patchPrepared(keys: newKeys, tx: &tx, patchNode: patchNode)
    }

    func patch(
        key newKey: _ViewKey,
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        pendingMakeNode = { _, viewContext, mountCtx in makeNode(viewContext, &mountCtx) }

        patchPrepared(keys: CollectionOfOne(newKey).span, tx: &tx) { _, node, tx in patchNode(node, &tx) }
    }

    private func patchPrepared(
        keys: borrowing Span<_ViewKey>,
        tx: inout _TransactionContext,
        patchNode: (Int, AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        prepareLaneCapacities(newCount: keys.count)

        removedMiddleSlots.removeAll(keepingCapacity: true)

        let didStructureChange = keyedDiff.run(
            activeSlots: &activeSlots,
            leavingSlots: &leavingSlots,
            removedSlots: &removedMiddleSlots,
            keys: keys,
            transaction: tx.transaction
        )

        while var slot = removedMiddleSlots.popLast() {
            switch slot.beginRemovalForDiff(tx: &tx, handle: containerHandle) {
            case .none: break
            case .removed(let removed): removedNodes.append(removed)
            case .leaving(let leavingSlot): leavingSlots.append(leavingSlot)
            }
        }

        for index in activeSlots.indices {
            activeSlots[index].patchInActiveLane(
                newKeyIndex: index,
                tx: &tx,
                containerHandle: containerHandle,
                patchNode: patchNode
            )
        }

        if didStructureChange {
            containerHandle?.reportLayoutChange(&tx)
        }
    }

    private func prepareLaneCapacities(newCount: Int) {
        let oldCount = activeSlots.count

        activeSlots.reserveCapacity(newCount)

        let removableUpperBound = oldCount
        leavingSlots.reserveCapacity(leavingSlots.count + removableUpperBound)
        removedNodes.reserveCapacity(removedNodes.count + removableUpperBound)
        removedMiddleSlots.reserveCapacity(removableUpperBound)
    }

    private func promoteReadyLeavingNodes() {
        leavingRemovalScratch.removeAll(keepingCapacity: true)
        leavingRemovalScratch.reserveCapacity(leavingSlots.count)

        for index in leavingSlots.indices {
            if let removed = leavingSlots[index].consumeRemovedIfReadyFromLeaving() {
                removedNodes.append(removed)
                leavingRemovalScratch.append(index)
            }
        }

        while let index = leavingRemovalScratch.popLast() {
            _ = leavingSlots.remove(at: index)
        }
    }
}

extension MountContainer {
    struct Slot: ~Copyable {
        struct Pending {
            var transaction: Transaction
            var newKeyIndex: Int
        }

        struct Mounted: ~Copyable {
            var node: AnyReconcilable
            var layoutNodes: RigidArray<LayoutNode>
            var didMove: Bool
            var transitionCoordinator: MountRootTransitionCoordinator?

            deinit {
                // NOTE: this is a load-bearing deinit
            }
        }

        enum SlotState: ~Copyable {
            case pending(Pending)
            case mounted(Mounted)
            case reviving(Mounted)
            case removed

            static func pending(transaction: Transaction, newKeyIndex: Int) -> Self {
                .pending(.init(transaction: transaction, newKeyIndex: newKeyIndex))
            }
        }

        enum RemovalForDiff: ~Copyable {
            case none
            case leaving(Slot)
            case removed(MountContainer.RemovedNode)
        }

        let key: _ViewKey
        var slotState: SlotState

        static func pending(
            key: _ViewKey,
            transaction: Transaction,
            newKeyIndex: Int
        ) -> Self {
            .init(
                key: key,
                slotState: .pending(transaction: transaction, newKeyIndex: newKeyIndex)
            )
        }

        static func mounted(
            key: _ViewKey,
            mounted: consuming Mounted
        ) -> Self {
            .init(key: key, slotState: .mounted(mounted))
        }

        @inline(__always)
        private mutating func takeState() -> SlotState {
            var state = SlotState.removed
            swap(&state, &slotState)
            return state
        }

        @inline(__always)
        private mutating func setPending(transaction: Transaction, newKeyIndex: Int) {
            slotState = .pending(transaction: transaction, newKeyIndex: newKeyIndex)
        }

        @inline(__always)
        private mutating func setMounted(_ mounted: consuming Mounted) {
            slotState = .mounted(mounted)
        }

        @inline(__always)
        private mutating func setRemoved() {
            slotState = .removed
        }

        @inline(__always)
        private static func reportLeavingElements(
            of mounted: borrowing Mounted,
            handle: LayoutContainer.Handle?,
            tx: inout _TransactionContext
        ) {
            let nodes = mounted.layoutNodes.span
            for index in nodes.indices {
                if case let .elementNode(element) = nodes[unchecked: index] {
                    handle?.reportLeavingElement(element, &tx)
                }
            }
        }

        @inline(__always)
        private static func reportReenteringElements(
            of mounted: borrowing Mounted,
            handle: LayoutContainer.Handle?,
            tx: inout _TransactionContext
        ) {
            let nodes = mounted.layoutNodes.span
            for index in nodes.indices {
                if case let .elementNode(element) = nodes[unchecked: index] {
                    handle?.reportReenteringElement(element, &tx)
                }
            }
        }

        mutating func markReviving() {
            let state = takeState()
            switch consume state {
            case .mounted(let mounted):
                slotState = .reviving(mounted)
            default:
                preconditionFailure("only mounted leaving slots can be marked for revival")
            }
        }

        mutating func patchInActiveLane(
            newKeyIndex: Int,
            tx: inout _TransactionContext,
            containerHandle: LayoutContainer.Handle?,
            patchNode: (Int, AnyReconcilable, inout _TransactionContext) -> Void
        ) {
            let state = takeState()

            switch consume state {
            case .pending:
                setPending(transaction: tx.transaction, newKeyIndex: newKeyIndex)
            case .mounted(let mounted):
                patchNode(newKeyIndex, mounted.node, &tx)
                setMounted(mounted)
            case .reviving(var mounted):
                mounted.transitionCoordinator?.cancelRemoval(tx: &tx)
                mounted.didMove = true
                Self.reportReenteringElements(of: mounted, handle: containerHandle, tx: &tx)
                patchNode(newKeyIndex, mounted.node, &tx)
                setMounted(mounted)
            case .removed:
                preconditionFailure("active lane contains removed slot")
            }
        }

        mutating func markMovedInActiveLane() {
            let state = takeState()

            switch consume state {
            case .pending(let pending):
                slotState = .pending(pending)
            case .mounted(let mounted):
                var mounted = mounted
                mounted.didMove = true
                setMounted(mounted)
            case .reviving:
                preconditionFailure("reviving slot should not appear in activeCells")
            case .removed:
                preconditionFailure("active lane contains removed slot")
            }
        }

        mutating func beginRemovalForDiff(
            tx: inout _TransactionContext,
            handle: LayoutContainer.Handle?
        ) -> RemovalForDiff {
            let state = takeState()

            switch consume state {
            case .pending:
                setRemoved()
                return .none

            case .mounted(let mounted):
                let shouldDeferRemoval = mounted.transitionCoordinator?.beginRemoval(tx: &tx, handle: handle) ?? false

                if shouldDeferRemoval {
                    Self.reportLeavingElements(of: mounted, handle: handle, tx: &tx)
                    return .leaving(.mounted(key: key, mounted: mounted))
                }

                setRemoved()
                return .removed(.init(mounted: mounted))

            case .reviving:
                preconditionFailure("reviving slot should not appear in removed slots")
            case .removed:
                preconditionFailure("active lane contains removed slot")
            }
        }

        mutating func consumeRemovedIfReadyFromLeaving() -> MountContainer.RemovedNode? {
            let state = takeState()

            switch consume state {
            case .mounted(let mounted):
                if mounted.transitionCoordinator?.consumeDeferredRemovalReadySignal() == true {
                    setRemoved()
                    return .init(mounted: mounted)
                }

                setMounted(mounted)
                return nil

            case .reviving:
                preconditionFailure("reviving slot should not appear in leaving lane")
            case .pending:
                preconditionFailure("leaving lane contains non-mounted slot")
            case .removed:
                preconditionFailure("leaving lane contains non-mounted slot")
            }
        }

        mutating func collectActive(
            into ops: inout LayoutPass,
            context: inout _CommitContext,
            viewContext: borrowing _ViewContext,
            makeNode: ((Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable)?,
            parentOp: LayoutPass.Entry.LayoutOp
        ) {
            let state = takeState()

            switch consume state {
            case .pending(let pending):
                guard let makeNode else {
                    preconditionFailure("pending slot requires a makeNode callback")
                }
                let mounted = context.withMountContext(transaction: pending.transaction) { (mountCtx: consuming _MountContext) in
                    mountCtx.makeMountedState(
                        newKeyIndex: pending.newKeyIndex,
                        viewContext: viewContext,
                        makeNode: makeNode
                    )
                }

                mounted.transitionCoordinator?.scheduleEnterIdentityIfNeeded(scheduler: context.scheduler)
                mounted.layoutNodes.collect(into: &ops, context: &context, op: .added)
                setMounted(mounted)

            case .mounted(let mounted):
                var mounted = mounted
                let childOp: LayoutPass.Entry.LayoutOp = mounted.didMove ? .moved : parentOp
                mounted.layoutNodes.collect(into: &ops, context: &context, op: childOp)
                mounted.didMove = false
                setMounted(mounted)

            case .reviving:
                preconditionFailure("reviving slot should have been resolved in patchInActiveLane")
            case .removed:
                preconditionFailure("active lane contains removed slot")
            }
        }

        mutating func unmount(_ context: inout _CommitContext) {
            let state = takeState()

            switch consume state {
            case .pending:
                setRemoved()
            case .mounted(let mounted):
                mounted.node.unmount(&context)
                setRemoved()
            case .reviving(let mounted):
                mounted.node.unmount(&context)
                setRemoved()
            case .removed:
                setRemoved()
            }
        }
    }

    struct RemovedNode: ~Copyable {
        var mounted: Slot.Mounted

        mutating func collectRemoved(into ops: inout LayoutPass, context: inout _CommitContext) {
            mounted.layoutNodes.collect(into: &ops, context: &context, op: .removed)
            mounted.node.unmount(&context)
        }

        mutating func unmount(_ context: inout _CommitContext) {
            mounted.node.unmount(&context)
        }
    }
}
