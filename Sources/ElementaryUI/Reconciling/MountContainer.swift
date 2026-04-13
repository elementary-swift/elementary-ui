import BasicContainers

final class MountContainer {
    private let viewContext: _ViewContext
    private var activeSlots: UniqueArray<Slot>
    private var leavingSlots: UniqueArray<Slot> = .init()
    private var removedNodes: UniqueArray<RemovedNode> = .init()

    var containerHandle: LayoutContainer.Handle?

    // TODO: get rid of these here...
    private var removedMiddleSlots: UniqueArray<Slot> = .init()
    private var leavingRemovalScratch: UniqueArray<Int> = .init()

    private init(context: borrowing _ViewContext, slots: consuming UniqueArray<Slot>) {
        self.viewContext = copy context
        self.activeSlots = slots
    }

    convenience init<Node: _Reconcilable & ~Copyable>(
        mountedKey key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.init(
            context: context,
            slots: UniqueArray<Slot>(capacity: 1) { span in
                let mountedSlot = ctx.withMountRootContext { rootCtx in
                    Slot.mounted(
                        key: key,
                        mounted: rootCtx.makeMountedSlot(
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

    convenience init<Node: _Reconcilable & ~Copyable>(
        mountedKeyStorage keys: borrowing Span<_ViewKey>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.init(
            context: context,
            slots: UniqueArray<Slot>(capacity: keys.count) { span in
                for index in keys.indices {
                    let mountedSlot = ctx.withMountRootContext { rootCtx in
                        Slot.mounted(
                            key: keys[unchecked: index],
                            mounted: rootCtx.makeMountedSlot(
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
                parentOp: op
            )
        }
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

        activeSlots.removeAll()
        leavingSlots.removeAll()
        removedNodes.removeAll()
        containerHandle = nil
    }

    func reportLayoutChange(_ tx: inout _TransactionContext) {
        containerHandle?.reportLayoutChange(&tx)
    }

    func patch(
        keys newKeys: borrowing Span<_ViewKey>,
        tx: inout _TransactionContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (Int, inout AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        patchPrepared(keys: newKeys, tx: &tx, makeNode: makeNode, patchNode: patchNode)
    }

    func patch(
        key newKey: _ViewKey,
        tx: inout _TransactionContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (inout AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        patchPrepared(
            keys: CollectionOfOne(newKey).span,
            tx: &tx,
            makeNode: { _, viewContext, mountCtx in makeNode(viewContext, &mountCtx) }
        ) { _, node, tx in
            patchNode(&node, &tx)
        }
    }

    private func patchPrepared(
        keys: borrowing Span<_ViewKey>,
        tx: inout _TransactionContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (Int, inout AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        prepareLaneCapacities(newCount: keys.count)

        removedMiddleSlots.removeAll(keepingCapacity: true)

        let didStructureChange = tx.scheduler.scratch.withDiffEngine { differ in
            differ.run(
                activeSlots: &activeSlots,
                leavingSlots: &leavingSlots,
                removedSlots: &removedMiddleSlots,
                keys: keys,
                makeNewSlot: { [viewContext] newKeyIndex, key in
                    var mounted = tx.scheduler.withMountContext(tx: &tx) { mountCtx in
                        mountCtx.makeMountedSlot(
                            newKeyIndex: newKeyIndex,
                            viewContext: viewContext,
                            makeNode: makeNode
                        )
                    }
                    mounted.transitionCoordinator?.scheduleEnterIdentityIfNeeded(scheduler: tx.scheduler)
                    mounted.placement = .added
                    return .mounted(key: key, mounted: mounted)
                }
            )
        }

        // TODO: fix this to move-only
        while var slot = removedMiddleSlots.popLast() {
            switch slot.beginRemovalForDiff(tx: &tx, handle: containerHandle) {
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
        struct Mounted: ~Copyable {
            enum Placement {
                case unchanged
                case added
                case moved
            }

            var node: AnyReconcilable
            var layoutNodes: RigidArray<LayoutNode>
            var placement: Placement
            var transitionCoordinator: MountRootTransitionCoordinator?

            deinit {
                // NOTE: this is a load-bearing deinit
            }
        }

        enum RemovalForDiff: ~Copyable {
            case leaving(Slot)
            case removed(MountContainer.RemovedNode)
        }

        private enum Storage: ~Copyable {
            case mounted(Mounted)
            case movedOut
        }

        let key: _ViewKey
        private var storage: Storage

        static func mounted(
            key: _ViewKey,
            mounted: consuming Mounted
        ) -> Self {
            .init(key: key, storage: .mounted(mounted))
        }

        @inline(__always)
        private mutating func takeMounted() -> Mounted {
            var storage = Storage.movedOut
            swap(&storage, &self.storage)

            switch consume storage {
            case .mounted(let mounted):
                return mounted
            case .movedOut:
                preconditionFailure("slot mounted state was already moved out")
            }
        }

        @inline(__always)
        private mutating func putMounted(_ mounted: consuming Mounted) {
            self.storage = .mounted(mounted)
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

        mutating func patchInActiveLane(
            newKeyIndex: Int,
            tx: inout _TransactionContext,
            containerHandle: LayoutContainer.Handle?,
            patchNode: (Int, inout AnyReconcilable, inout _TransactionContext) -> Void
        ) {
            var mounted = takeMounted()

            if mounted.transitionCoordinator?.isRemovalInFlight == true {
                mounted.transitionCoordinator?.cancelRemoval(tx: &tx)
                Self.reportReenteringElements(of: mounted, handle: containerHandle, tx: &tx)
                mounted.placement = .moved
            }

            patchNode(newKeyIndex, &mounted.node, &tx)
            putMounted(consume mounted)
        }

        mutating func markMovedInActiveLane() {
            var mounted = takeMounted()

            if mounted.placement == .unchanged {
                mounted.placement = .moved
            }
            putMounted(consume mounted)
        }

        mutating func beginRemovalForDiff(
            tx: inout _TransactionContext,
            handle: LayoutContainer.Handle?
        ) -> RemovalForDiff {
            let mounted = takeMounted()

            if mounted.placement == .added {
                return .removed(.init(mounted: mounted, shouldCollectLayout: false))
            }

            let shouldDeferRemoval = mounted.transitionCoordinator?.beginRemoval(tx: &tx, handle: handle) ?? false

            if shouldDeferRemoval {
                Self.reportLeavingElements(of: mounted, handle: handle, tx: &tx)
                return .leaving(.mounted(key: key, mounted: mounted))
            }

            return .removed(.init(mounted: mounted))
        }

        mutating func consumeRemovedIfReadyFromLeaving() -> MountContainer.RemovedNode? {
            let mounted = takeMounted()

            if mounted.transitionCoordinator?.consumeDeferredRemovalReadySignal() == true {
                return .init(mounted: mounted)
            }

            putMounted(consume mounted)
            return nil
        }

        mutating func collectActive(
            into ops: inout LayoutPass,
            context: inout _CommitContext,
            parentOp: LayoutPass.Entry.LayoutOp
        ) {
            var mounted = takeMounted()

            let childOp: LayoutPass.Entry.LayoutOp
            switch mounted.placement {
            case .unchanged:
                childOp = parentOp
            case .added:
                childOp = .added
            case .moved:
                childOp = .moved
            }
            mounted.layoutNodes.collect(into: &ops, context: &context, op: childOp)
            mounted.placement = .unchanged
            putMounted(consume mounted)
        }

        mutating func unmount(_ context: inout _CommitContext) {
            let mounted = takeMounted()
            mounted.node.unmount(&context)
        }
    }

    struct RemovedNode: ~Copyable {
        var mounted: Slot.Mounted
        var shouldCollectLayout: Bool = true

        mutating func collectRemoved(into ops: inout LayoutPass, context: inout _CommitContext) {
            if shouldCollectLayout {
                mounted.layoutNodes.collect(into: &ops, context: &context, op: .removed)
            }
            mounted.node.unmount(&context)
        }

        mutating func unmount(_ context: inout _CommitContext) {
            mounted.node.unmount(&context)
        }

        deinit {
            // NOTE: this is a load-bearing deinit
        }
    }
}
