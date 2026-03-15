final class MountContainer {
    private struct ActiveInfo {
        var slot: Slot
        var sourceIndex: Int
        var oldActiveOffset: Int
    }

    private struct LeavingAnchor {
        var key: _ViewKey
        var sourceIndex: Int
        var anchorActiveOffset: Int
    }

    private let viewContext: _ViewContext
    private var slots: [Slot]
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
        let newKeysArray = Array(newKeys)

        var newKeyToIndex: [_ViewKey: Int] = [:]
        newKeyToIndex.reserveCapacity(newKeysArray.count)
        for (index, key) in newKeysArray.enumerated() {
            // duplicate keys are undefined behavior
            newKeyToIndex[key] = index
        }

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

        var activeByKey: [_ViewKey: ActiveInfo] = [:]
        activeByKey.reserveCapacity(slots.count)
        var leavingByKey: [_ViewKey: Slot] = [:]
        leavingByKey.reserveCapacity(slots.count)
        var leavingAnchors: [LeavingAnchor] = []
        leavingAnchors.reserveCapacity(slots.count)

        var activeOffset = 0
        for (sourceIndex, slot) in slots.enumerated() {
            if slot.isActiveForPatch {
                activeByKey[slot.key] = .init(
                    slot: slot,
                    sourceIndex: sourceIndex,
                    oldActiveOffset: activeOffset
                )
                activeOffset += 1
            } else if slot.isLeavingInline {
                leavingByKey[slot.key] = slot
                leavingAnchors.append(
                    .init(
                        key: slot.key,
                        sourceIndex: sourceIndex,
                        anchorActiveOffset: activeOffset
                    )
                )
            }
        }

        let activeKeysSnapshot = Array(activeByKey.keys)
        for key in activeKeysSnapshot where newKeyToIndex[key] == nil {
            guard var removed = activeByKey.removeValue(forKey: key) else { continue }
            didStructureChange = true

            if removed.slot.isMounted {
                reportLayoutChangeIfNeeded(&tx, &didReportLayoutChange)
            }
            _ = removed.slot.beginLeaving(tx: &tx, handle: containerHandle)

            if removed.slot.isLeavingInline {
                leavingByKey[key] = removed.slot
                leavingAnchors.append(
                    .init(
                        key: key,
                        sourceIndex: removed.sourceIndex,
                        anchorActiveOffset: removed.oldActiveOffset
                    )
                )
            }
        }

        var targetActiveSlots: [Slot] = []
        targetActiveSlots.reserveCapacity(newKeysArray.count)

        for (newActiveOffset, key) in newKeysArray.enumerated() {
            if var reusedActive = activeByKey.removeValue(forKey: key) {
                switch reusedActive.slot.slotState {
                case .pending:
                    reusedActive.slot.overwritePending(
                        transaction: tx.transaction,
                        create: { context, mountCtx in
                            AnyReconcilable(makeNode(newActiveOffset, context, &mountCtx))
                        }
                    )
                case .mounted:
                    if reusedActive.oldActiveOffset != newActiveOffset {
                        reusedActive.slot.markMoved()
                        didStructureChange = true
                    }
                case .removed:
                    reusedActive.slot.overwritePending(
                        transaction: tx.transaction,
                        create: { context, mountCtx in
                            AnyReconcilable(makeNode(newActiveOffset, context, &mountCtx))
                        }
                    )
                }
                targetActiveSlots.append(reusedActive.slot)
            } else if var revived = leavingByKey.removeValue(forKey: key) {
                reportLayoutChangeIfNeeded(&tx, &didReportLayoutChange)
                _ = revived.reviveFromLeaving(tx: &tx, handle: containerHandle)
                didStructureChange = true
                targetActiveSlots.append(revived)
            } else {
                targetActiveSlots.append(
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

        leavingAnchors.sort { lhs, rhs in
            lhs.sourceIndex < rhs.sourceIndex
        }

        var leavingByOffset: [Int: [Slot]] = [:]
        leavingByOffset.reserveCapacity(leavingAnchors.count)
        for anchor in leavingAnchors {
            guard let slot = leavingByKey[anchor.key] else { continue }
            let boundedOffset = min(anchor.anchorActiveOffset, targetActiveSlots.count)
            leavingByOffset[boundedOffset, default: []].append(slot)
        }

        var rebuiltSlots: [Slot] = []
        rebuiltSlots.reserveCapacity(targetActiveSlots.count + leavingByKey.count)
        for activeIndex in 0...targetActiveSlots.count {
            if let leavingSlots = leavingByOffset[activeIndex] {
                rebuiltSlots.append(contentsOf: leavingSlots)
            }
            if activeIndex < targetActiveSlots.count {
                rebuiltSlots.append(targetActiveSlots[activeIndex])
            }
        }
        slots = rebuiltSlots

        var activeSlotIndicesByKey: [_ViewKey: Int] = [:]
        activeSlotIndicesByKey.reserveCapacity(newKeysArray.count)
        for index in slots.indices where slots[index].isActiveForPatch {
            activeSlotIndicesByKey[slots[index].key] = index
        }

        for (index, key) in newKeysArray.enumerated() {
            guard let slotIndex = activeSlotIndicesByKey[key] else { continue }
            _ = slots[slotIndex].patchMountedIfActive(as: Node.self) { node in
                patchNode(index, &node, &tx)
            }
        }

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
                let (layoutNodes, transitionCoordinator) = rootCtx.takeMountedOutput()
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
                for element in mountedElementReferences(mounted.layoutNodes) {
                    handle?.reportLeavingElement(element, &tx)
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

            for element in mountedElementReferences(mounted.layoutNodes) {
                handle?.reportReenteringElement(element, &tx)
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
                    let (layoutNodes, transitionCoordinator) = mountCtx.takeMountedOutput()
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

        private func mountedElementReferences(_ layoutNodes: [LayoutNode]) -> [DOM.Node] {
            var elements: [DOM.Node] = []
            elements.reserveCapacity(layoutNodes.count)

            for node in layoutNodes {
                switch node {
                case .elementNode(let ref):
                    elements.append(ref)
                case .textNode, .container:
                    break
                }
            }
            return elements
        }
    }

}
