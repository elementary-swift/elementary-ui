// TODO: optimize this, currently a bit AI-sloppy
final class MountContainer {
    private struct ActiveIndexInfo {
        var slotIndex: Int
        var oldActiveOffset: Int
    }

    private let viewContext: _ViewContext
    private var slots: [Slot]
    private var scratchIncomingKeys: [_ViewKey] = []
    private var scratchIncomingKeySet: Set<_ViewKey> = []
    private var scratchActiveByKey: [_ViewKey: ActiveIndexInfo] = [:]
    private var scratchLeavingByKey: [_ViewKey: Int] = [:]
    private var scratchSlots: [Slot] = []
    private var scratchTargetActive: [Slot] = []
    var containerHandle: LayoutContainer.Handle?

    private init(context: borrowing _ViewContext, slots: [Slot]) {
        self.viewContext = copy context
        self.slots = slots
    }

    convenience init<Node: _Reconcilable>(
        mountedKey key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.init(
            context: context,
            slots: [
                Slot.mounted(
                    key: key,
                    index: 0,
                    viewContext: context,
                    ctx: &ctx,
                    makeNode: { _, context, mountCtx in
                        makeNode(context, &mountCtx)
                    }
                )
            ]
        )
    }

    convenience init<Node: _Reconcilable>(
        mountedKeys keys: some Collection<_ViewKey>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        guard !keys.isEmpty else {
            self.init(context: context, slots: [])
            return
        }
        self.init(
            context: context,
            slots: keys.enumerated().map { (index, key) in
                Slot.mounted(
                    key: key,
                    index: index,
                    viewContext: context,
                    ctx: &ctx,
                    makeNode: makeNode
                )
            }
        )
    }

    func collect(into ops: inout LayoutPass, context: inout _CommitContext) {
        if containerHandle == nil { containerHandle = ops.containerHandle }

        for index in slots.indices {
            slots[index].collect(into: &ops, context: &context, viewContext: viewContext)
        }

        slots.removeAll { $0.isRemoved }
    }

    func unmount(_ context: inout _CommitContext) {
        for index in slots.indices {
            slots[index].unmount(&context)
        }
        slots.removeAll()
    }

    func reportLayoutChange(_ tx: inout _TransactionContext) {
        containerHandle?.reportLayoutChange(&tx)
    }

    func patch<Node: _Reconcilable>(
        keys newKeys: some BidirectionalCollection<_ViewKey>,
        tx: inout _TransactionContext,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> Node,
        patchNode: (Int, inout Node, inout _TransactionContext) -> Void
    ) {
        scratchIncomingKeys.removeAll(keepingCapacity: true)
        scratchIncomingKeys.append(contentsOf: newKeys)

        scratchIncomingKeySet.removeAll(keepingCapacity: true)
        scratchIncomingKeySet.formUnion(scratchIncomingKeys)

        var didStructureChange = false
        var didReportLayoutChange = false

        func reportLayoutChangeIfNeeded(
            _ tx: inout _TransactionContext,
            _ didReportLayoutChange: inout Bool
        ) {
            if !didReportLayoutChange {
                reportLayoutChange(&tx)
                didReportLayoutChange = true
            }
        }

        scratchActiveByKey.removeAll(keepingCapacity: true)
        scratchActiveByKey.reserveCapacity(slots.count)
        scratchLeavingByKey.removeAll(keepingCapacity: true)
        scratchLeavingByKey.reserveCapacity(slots.count)

        var activeOffset = 0
        for slotIndex in slots.indices {
            if slots[slotIndex].isActiveForPatch {
                let key = slots[slotIndex].key

                if !scratchIncomingKeySet.contains(key) {
                    didStructureChange = true

                    if slots[slotIndex].isMounted {
                        reportLayoutChangeIfNeeded(&tx, &didReportLayoutChange)
                    }
                    _ = slots[slotIndex].beginLeaving(tx: &tx, handle: containerHandle)
                    if slots[slotIndex].isLeavingInline {
                        scratchLeavingByKey[key] = slotIndex
                    }
                } else {
                    scratchActiveByKey[key] = .init(
                        slotIndex: slotIndex,
                        oldActiveOffset: activeOffset
                    )
                }

                activeOffset += 1
            } else if slots[slotIndex].isLeavingInline {
                scratchLeavingByKey[slots[slotIndex].key] = slotIndex
            }
        }

        scratchTargetActive.removeAll(keepingCapacity: true)
        scratchTargetActive.reserveCapacity(scratchIncomingKeys.count)

        for (newActiveOffset, key) in scratchIncomingKeys.enumerated() {
            if let reusedActive = scratchActiveByKey.removeValue(forKey: key) {
                var slot = slots[reusedActive.slotIndex]

                switch slot.slotState {
                case .pending:
                    slot.overwritePending(
                        transaction: tx.transaction,
                        create: { context, mountCtx in
                            AnyReconcilable(makeNode(newActiveOffset, context, &mountCtx))
                        }
                    )
                case .mounted:
                    if reusedActive.oldActiveOffset != newActiveOffset {
                        slot.markMoved()
                        didStructureChange = true
                    }
                    _ = slot.patchMountedIfActive(as: Node.self) { node in
                        patchNode(newActiveOffset, &node, &tx)
                    }
                case .removed:
                    slot.overwritePending(
                        transaction: tx.transaction,
                        create: { context, mountCtx in
                            AnyReconcilable(makeNode(newActiveOffset, context, &mountCtx))
                        }
                    )
                }

                scratchTargetActive.append(slot)
            } else if let leavingIndex = scratchLeavingByKey.removeValue(forKey: key) {
                var revived = slots[leavingIndex]
                reportLayoutChangeIfNeeded(&tx, &didReportLayoutChange)
                _ = revived.reviveFromLeaving(tx: &tx, handle: containerHandle)
                didStructureChange = true
                _ = revived.patchMountedIfActive(as: Node.self) { node in
                    patchNode(newActiveOffset, &node, &tx)
                }
                slots[leavingIndex] = revived
                scratchTargetActive.append(revived)
            } else {
                scratchTargetActive.append(
                    Slot.pending(
                        key: key,
                        transaction: tx.transaction,
                        create: { context, mountCtx in
                            AnyReconcilable(makeNode(newActiveOffset, context, &mountCtx))
                        }
                    )
                )
                didStructureChange = true
            }
        }

        scratchSlots.removeAll(keepingCapacity: true)
        scratchSlots.reserveCapacity(max(slots.count, scratchTargetActive.count))

        var activeCursor = 0
        for slot in slots {
            if slot.isLeavingInline {
                scratchSlots.append(slot)
            } else if activeCursor < scratchTargetActive.count {
                scratchSlots.append(scratchTargetActive[activeCursor])
                activeCursor += 1
            }
        }

        if activeCursor < scratchTargetActive.count {
            scratchSlots.append(contentsOf: scratchTargetActive[activeCursor...])
        }

        swap(&slots, &scratchSlots)
        scratchSlots.removeAll(keepingCapacity: true)

        if didStructureChange, !didReportLayoutChange {
            reportLayoutChange(&tx)
        }
    }
}

extension MountContainer {

    private struct Slot {
        struct Pending {
            var transaction: Transaction
            var create: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
        }

        struct Mounted {
            enum MountState {
                case active
                case leaving
                case left
            }

            var node: AnyReconcilable
            var layoutNodes: [LayoutNode]
            var mountState: MountState
            var didMove: Bool
            var transitionCoordinator: MountRootTransitionCoordinator?
        }

        enum SlotState {
            case pending(Pending)
            case mounted(Mounted)
            case removed
        }

        var key: _ViewKey
        var slotState: SlotState

        var isRemoved: Bool {
            if case .removed = slotState { return true }
            return false
        }

        var isActiveForPatch: Bool {
            switch slotState {
            case .pending:
                return true
            case .mounted(let mounted):
                return mounted.mountState == .active
            case .removed:
                return false
            }
        }

        var isMounted: Bool {
            if case .mounted = slotState { return true }
            return false
        }

        var isLeavingInline: Bool {
            switch slotState {
            case .mounted(let mounted):
                return mounted.mountState == .leaving || mounted.mountState == .left
            case .pending, .removed:
                return false
            }
        }

        static func pending(
            key: _ViewKey,
            transaction: Transaction,
            create: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
        ) -> Self {
            .init(
                key: key,
                slotState: .pending(
                    .init(transaction: transaction, create: create)
                )
            )
        }

        static func mounted<Node: _Reconcilable>(
            key: _ViewKey,
            index: Int,
            viewContext: borrowing _ViewContext,
            ctx: inout _MountContext,
            makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
        ) -> Self {
            let context = copy viewContext
            let (node, layoutNodes, transitionCoordinator) = ctx.withMountRootContext { (rootCtx: consuming _MountContext) in
                var rootCtx = consume rootCtx
                let node = AnyReconcilable(makeNode(index, context, &rootCtx))
                let (layoutNodes, transitionCoordinator) = rootCtx.takeMountOutput()
                return (node, layoutNodes, transitionCoordinator)
            }

            return .init(
                key: key,
                slotState: .mounted(
                    .init(
                        node: node,
                        layoutNodes: layoutNodes,
                        mountState: .active,
                        didMove: false,
                        transitionCoordinator: transitionCoordinator
                    )
                )
            )
        }

        mutating func overwritePending(
            transaction: Transaction,
            create: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
        ) {
            slotState = .pending(.init(transaction: transaction, create: create))
        }

        mutating func markMoved() {
            guard case .mounted(var mounted) = slotState else { return }
            mounted.didMove = true
            slotState = .mounted(mounted)
        }

        @discardableResult
        mutating func beginLeaving(
            tx: inout _TransactionContext,
            handle: LayoutContainer.Handle?
        ) -> Bool {
            switch slotState {
            case .pending:
                slotState = .removed
                return false
            case .mounted(var mounted):
                for layoutNode in mounted.layoutNodes {
                    if case let .elementNode(element) = layoutNode {
                        handle?.reportLeavingElement(element, &tx)
                    }
                }

                let shouldDeferRemoval = mounted.transitionCoordinator?.beginRemoval(tx: &tx, handle: handle) ?? false
                mounted.mountState = shouldDeferRemoval ? .leaving : .left
                slotState = .mounted(mounted)
                return true
            case .removed:
                return false
            }
        }

        @discardableResult
        mutating func reviveFromLeaving(
            tx: inout _TransactionContext,
            handle: LayoutContainer.Handle?
        ) -> Bool {
            guard case .mounted(var mounted) = slotState else { return false }

            switch mounted.mountState {
            case .active:
                return false
            case .leaving, .left:
                break
            }

            mounted.transitionCoordinator?.cancelRemoval(tx: &tx)
            mounted.mountState = .active
            mounted.didMove = true

            for layoutNode in mounted.layoutNodes {
                if case let .elementNode(element) = layoutNode {
                    handle?.reportReenteringElement(element, &tx)
                }
            }

            slotState = .mounted(mounted)
            return true
        }

        mutating func collect(
            into ops: inout LayoutPass,
            context: inout _CommitContext,
            viewContext: borrowing _ViewContext
        ) {
            switch slotState {
            case .pending(let pending):
                let contextCopy = copy viewContext
                let (node, layoutNodes, transitionCoordinator) = context.withMountContext(transaction: pending.transaction) { mountCtx in
                    var mountCtx = consume mountCtx
                    let node = pending.create(contextCopy, &mountCtx)
                    let (layoutNodes, transitionCoordinator) = mountCtx.takeMountOutput()
                    return (node, layoutNodes, transitionCoordinator)
                }

                transitionCoordinator?.scheduleEnterIdentityIfNeeded(scheduler: context.scheduler)

                let mounted = Mounted(
                    node: node,
                    layoutNodes: layoutNodes,
                    mountState: .active,
                    didMove: false,
                    transitionCoordinator: transitionCoordinator
                )
                collectLayoutNodes(mounted.layoutNodes, kind: .added, into: &ops, context: &context)
                slotState = .mounted(mounted)

            case .mounted(var mounted):
                if case .leaving = mounted.mountState,
                    mounted.transitionCoordinator?.consumeDeferredRemovalReadySignal() == true
                {
                    mounted.mountState = .left
                }

                let kind: LayoutPass.Entry.Status
                switch mounted.mountState {
                case .active:
                    kind = mounted.didMove ? .moved : .unchanged
                case .leaving:
                    kind = .unchanged
                case .left:
                    kind = .removed
                }

                collectLayoutNodes(mounted.layoutNodes, kind: kind, into: &ops, context: &context)

                switch mounted.mountState {
                case .active:
                    mounted.didMove = false
                    slotState = .mounted(mounted)
                case .leaving:
                    slotState = .mounted(mounted)
                case .left:
                    mounted.node.unmount(&context)
                    slotState = .removed
                }

            case .removed:
                break
            }
        }

        mutating func unmount(_ context: inout _CommitContext) {
            guard case let .mounted(mounted) = slotState else {
                slotState = .removed
                return
            }

            mounted.node.unmount(&context)
            slotState = .removed
        }

        @discardableResult
        func patchMountedIfActive<Node: _Reconcilable>(
            as type: Node.Type = Node.self,
            _ body: (inout Node) -> Void
        ) -> Bool {
            _ = type
            guard case let .mounted(mounted) = slotState,
                mounted.mountState == .active
            else {
                return false
            }

            mounted.node.modify(as: Node.self, body)
            return true
        }

        private func collectLayoutNodes(
            _ layoutNodes: [LayoutNode],
            kind: LayoutPass.Entry.Status,
            into ops: inout LayoutPass,
            context: inout _CommitContext
        ) {
            let startIndex = ops.entries.count
            for layoutNode in layoutNodes {
                layoutNode.collect(into: &ops, context: &context)
            }

            guard kind != .unchanged else { return }
            for entryIndex in startIndex..<ops.entries.count {
                let entry = ops.entries[entryIndex]
                ops.entries[entryIndex] = .init(kind: kind, reference: entry.reference, type: entry.type)
            }
            ops.recomputeBatchFlags()
        }
    }

}
