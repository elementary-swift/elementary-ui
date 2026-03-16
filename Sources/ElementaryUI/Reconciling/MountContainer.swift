final class MountContainer {
    private let viewContext: _ViewContext
    private var slots: [Slot]
    var containerHandle: LayoutContainer.Handle?

    private var scratchOldMiddle: [Int] = []
    private var scratchSources: [Int] = []
    private var scratchOldKeyMap: [_ViewKey: Int] = [:]
    private var scratchLeavingByKey: [_ViewKey: Int] = [:]
    private var scratchNewMiddle: [Slot] = []
    private var scratchMiddleResult: [Slot] = []

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

    func collect(into ops: inout LayoutPass, context: inout _CommitContext, op: LayoutPass.Entry.LayoutOp) {
        if containerHandle == nil { containerHandle = ops.containerHandle }

        for index in slots.indices {
            slots[index].collect(into: &ops, context: &context, viewContext: viewContext, parentOp: op)
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

    // MARK: - Patch (thin generic wrapper)

    func patch<Node: _Reconcilable>(
        keys newKeys: some BidirectionalCollection<_ViewKey>,
        tx: inout _TransactionContext,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> Node,
        patchNode: (Int, inout Node, inout _TransactionContext) -> Void
    ) {
        let startIndex = newKeys.startIndex
        _performDiff(
            newKeyCount: newKeys.count,
            newKey: { newKeys[newKeys.index(startIndex, offsetBy: $0)] },
            tx: &tx,
            patchSlot: { slotIndex, newKeyIndex, tx in
                switch self.slots[slotIndex].slotState {
                case .pending, .removed:
                    self.slots[slotIndex].overwritePending(
                        transaction: tx.transaction,
                        create: { context, mountCtx in
                            AnyReconcilable(makeNode(newKeyIndex, context, &mountCtx))
                        }
                    )
                case .mounted:
                    _ = self.slots[slotIndex].patchMountedIfActive(as: Node.self) { node in
                        patchNode(newKeyIndex, &node, &tx)
                    }
                }
            },
            makeNewSlot: { key, newKeyIndex, transaction in
                .pending(key: key, transaction: transaction) { context, mountCtx in
                    AnyReconcilable(makeNode(newKeyIndex, context, &mountCtx))
                }
            }
        )
    }

    // MARK: - Non-generic diff engine (prefix/suffix + LIS)

    private func _performDiff(
        newKeyCount: Int,
        newKey: (Int) -> _ViewKey,
        tx: inout _TransactionContext,
        patchSlot: (_ slotIndex: Int, _ newKeyIndex: Int, _ tx: inout _TransactionContext) -> Void,
        makeNewSlot: (_ key: _ViewKey, _ newKeyIndex: Int, _ transaction: Transaction) -> Slot
    ) {
        let oldCount = slots.count
        if oldCount == 0 && newKeyCount == 0 { return }

        scratchLeavingByKey.removeAll(keepingCapacity: true)
        for i in slots.indices where slots[i].isLeavingInline {
            scratchLeavingByKey[slots[i].key] = i
        }

        // ── Phase 1: Common prefix ──────────────────────────────────────
        var fwdSlot = 0
        var fwdKey = 0
        while fwdSlot < oldCount && fwdKey < newKeyCount {
            if !slots[fwdSlot].isActiveForPatch { fwdSlot += 1; continue }
            guard slots[fwdSlot].key == newKey(fwdKey) else { break }
            patchSlot(fwdSlot, fwdKey, &tx)
            fwdSlot += 1; fwdKey += 1
        }

        // ── Phase 2: Common suffix ──────────────────────────────────────
        var bwdSlot = oldCount - 1
        var bwdKey = newKeyCount - 1
        while bwdSlot >= fwdSlot && bwdKey >= fwdKey {
            if !slots[bwdSlot].isActiveForPatch { bwdSlot -= 1; continue }
            guard slots[bwdSlot].key == newKey(bwdKey) else { break }
            bwdSlot -= 1; bwdKey -= 1
        }

        // ── Phase 3: Patch suffix in-place (before middle modifies structure) ─
        do {
            var ss = bwdSlot + 1
            var sk = bwdKey + 1
            while ss < oldCount && sk < newKeyCount {
                if !slots[ss].isActiveForPatch { ss += 1; continue }
                patchSlot(ss, sk, &tx)
                ss += 1; sk += 1
            }
        }

        // ── Determine middle extents ────────────────────────────────────
        let newMiddleCount = max(0, bwdKey - fwdKey + 1)

        scratchOldMiddle.removeAll(keepingCapacity: true)
        if fwdSlot <= bwdSlot {
            for i in fwdSlot...bwdSlot where slots[i].isActiveForPatch {
                scratchOldMiddle.append(i)
            }
        }
        let oldMiddleCount = scratchOldMiddle.count

        if oldMiddleCount == 0 && newMiddleCount == 0 { return }

        // ── Phase 4: Process middle ─────────────────────────────────────
        var didStructureChange = false
        var didReportLayoutChange = false

        if oldMiddleCount == 0 {
            // Pure insertions
            didStructureChange = true
            scratchNewMiddle.removeAll(keepingCapacity: true)
            scratchNewMiddle.reserveCapacity(newMiddleCount)
            for j in 0..<newMiddleCount {
                let keyIdx = fwdKey + j
                let key = newKey(keyIdx)
                if let leavingIdx = scratchLeavingByKey.removeValue(forKey: key) {
                    if !didReportLayoutChange { reportLayoutChange(&tx); didReportLayoutChange = true }
                    _ = slots[leavingIdx].reviveFromLeaving(tx: &tx, handle: containerHandle)
                    patchSlot(leavingIdx, keyIdx, &tx)
                    scratchNewMiddle.append(slots[leavingIdx])
                    if leavingIdx < fwdSlot || leavingIdx > bwdSlot {
                        slots[leavingIdx].slotState = .removed
                    }
                } else {
                    scratchNewMiddle.append(makeNewSlot(key, keyIdx, tx.transaction))
                }
            }

        } else if newMiddleCount == 0 {
            // Pure removals
            didStructureChange = true
            scratchNewMiddle.removeAll(keepingCapacity: true)
            for localIdx in 0..<oldMiddleCount {
                let slotIdx = scratchOldMiddle[localIdx]
                if slots[slotIdx].isMounted && !didReportLayoutChange {
                    reportLayoutChange(&tx); didReportLayoutChange = true
                }
                _ = slots[slotIdx].beginLeaving(tx: &tx, handle: containerHandle)
            }

        } else {
            // General case: keyed diff with LIS
            scratchOldKeyMap.removeAll(keepingCapacity: true)
            scratchOldKeyMap.reserveCapacity(oldMiddleCount)
            for localIdx in 0..<oldMiddleCount {
                scratchOldKeyMap[slots[scratchOldMiddle[localIdx]].key] = localIdx
            }

            scratchSources.removeAll(keepingCapacity: true)
            scratchSources.reserveCapacity(newMiddleCount)
            for j in 0..<newMiddleCount {
                let keyIdx = fwdKey + j
                let key = newKey(keyIdx)
                if let oldLocalIdx = scratchOldKeyMap.removeValue(forKey: key) {
                    scratchSources.append(oldLocalIdx)
                    patchSlot(scratchOldMiddle[oldLocalIdx], keyIdx, &tx)
                } else {
                    scratchSources.append(-1)
                }
            }

            // Begin leaving for unreused old middle slots (keys still in map)
            for (_, oldLocalIdx) in scratchOldKeyMap {
                let slotIdx = scratchOldMiddle[oldLocalIdx]
                didStructureChange = true
                if slots[slotIdx].isMounted && !didReportLayoutChange {
                    reportLayoutChange(&tx); didReportLayoutChange = true
                }
                _ = slots[slotIdx].beginLeaving(tx: &tx, handle: containerHandle)
            }

            // Mark revivable leaving slots (encode slot index as -(idx+2))
            for j in 0..<newMiddleCount where scratchSources[j] < 0 {
                let key = newKey(fwdKey + j)
                if let leavingIdx = scratchLeavingByKey[key] {
                    scratchSources[j] = -(leavingIdx + 2)
                }
                didStructureChange = true
            }

            // Compute LIS on reused-slot positions → nodes in the LIS don't move
            let inLIS = Self._longestIncreasingSubsequence(scratchSources)

            for j in 0..<newMiddleCount {
                if scratchSources[j] >= 0 && !inLIS[j] {
                    slots[scratchOldMiddle[scratchSources[j]]].markMoved()
                    didStructureChange = true
                }
            }

            // Build new middle active array in target order
            scratchNewMiddle.removeAll(keepingCapacity: true)
            scratchNewMiddle.reserveCapacity(newMiddleCount)
            for j in 0..<newMiddleCount {
                let keyIdx = fwdKey + j
                let key = newKey(keyIdx)
                let src = scratchSources[j]
                if src >= 0 {
                    scratchNewMiddle.append(slots[scratchOldMiddle[src]])
                } else if src < -1 {
                    let leavingIdx = -(src + 2)
                    if !didReportLayoutChange { reportLayoutChange(&tx); didReportLayoutChange = true }
                    _ = slots[leavingIdx].reviveFromLeaving(tx: &tx, handle: containerHandle)
                    patchSlot(leavingIdx, keyIdx, &tx)
                    scratchNewMiddle.append(slots[leavingIdx])
                    if leavingIdx < fwdSlot || leavingIdx > bwdSlot {
                        slots[leavingIdx].slotState = .removed
                    }
                } else {
                    scratchNewMiddle.append(makeNewSlot(key, keyIdx, tx.transaction))
                }
            }
        }

        // ── Phase 5: Reassemble middle ──────────────────────────────────
        if fwdSlot <= bwdSlot {
            scratchMiddleResult.removeAll(keepingCapacity: true)
            scratchMiddleResult.reserveCapacity(max(bwdSlot - fwdSlot + 1, scratchNewMiddle.count))
            var activeCursor = 0
            for i in fwdSlot...bwdSlot {
                if slots[i].isLeavingInline {
                    scratchMiddleResult.append(slots[i])
                } else if !slots[i].isRemoved && activeCursor < scratchNewMiddle.count {
                    scratchMiddleResult.append(scratchNewMiddle[activeCursor])
                    activeCursor += 1
                }
            }
            while activeCursor < scratchNewMiddle.count {
                scratchMiddleResult.append(scratchNewMiddle[activeCursor])
                activeCursor += 1
            }
            slots.replaceSubrange(fwdSlot...bwdSlot, with: scratchMiddleResult)
        } else if !scratchNewMiddle.isEmpty {
            slots.insert(contentsOf: scratchNewMiddle, at: fwdSlot)
        }

        scratchNewMiddle.removeAll(keepingCapacity: true)
        scratchMiddleResult.removeAll(keepingCapacity: true)

        if didStructureChange && !didReportLayoutChange {
            reportLayoutChange(&tx)
        }
    }

    // MARK: - Longest Increasing Subsequence (O(n log n))

    private static func _longestIncreasingSubsequence(_ sources: [Int]) -> [Bool] {
        let n = sources.count
        guard n > 0 else { return [] }

        var result = [Bool](repeating: false, count: n)
        var tails: [Int] = []
        var tailIdx: [Int] = []
        var preds = [Int](repeating: -1, count: n)

        for i in 0..<n {
            let val = sources[i]
            guard val >= 0 else { continue }

            var lo = 0
            var hi = tails.count
            while lo < hi {
                let mid = (lo + hi) &>> 1
                if tails[mid] < val { lo = mid + 1 } else { hi = mid }
            }

            if lo == tails.count {
                tails.append(val)
                tailIdx.append(i)
            } else {
                tails[lo] = val
                tailIdx[lo] = i
            }

            preds[i] = lo > 0 ? tailIdx[lo - 1] : -1
        }

        if !tails.isEmpty {
            var pos = tailIdx[tails.count - 1]
            while pos >= 0 {
                result[pos] = true
                pos = preds[pos]
            }
        }

        return result
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
            viewContext: borrowing _ViewContext,
            parentOp: LayoutPass.Entry.LayoutOp
        ) {
            switch slotState {
            case .pending(let pending):
                let viewContext = copy viewContext
                let (node, layoutNodes, transitionCoordinator) =
                    context.withMountContext(transaction: pending.transaction) { (ctx: consuming _MountContext) in
                        let node = pending.create(viewContext, &ctx)
                        let (layoutNodes, transitionCoordinator) = ctx.takeMountOutput()
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
                mounted.layoutNodes.collect(into: &ops, context: &context, op: .added)
                slotState = .mounted(mounted)

            case .mounted(var mounted):
                if case .leaving = mounted.mountState,
                    mounted.transitionCoordinator?.consumeDeferredRemovalReadySignal() == true
                {
                    mounted.mountState = .left
                }

                let childOp: LayoutPass.Entry.LayoutOp
                switch mounted.mountState {
                case .active:
                    childOp = mounted.didMove ? .moved : parentOp
                case .leaving:
                    childOp = parentOp
                case .left:
                    childOp = .removed
                }

                mounted.layoutNodes.collect(into: &ops, context: &context, op: childOp)

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
    }

}
