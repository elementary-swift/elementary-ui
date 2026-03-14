final class MountRootContainer {
    private enum SlotState {
        case active
        case leaving
    }

    private struct Slot {
        var key: _ViewKey
        var state: SlotState
        var root: MountRoot
    }

    private let viewContext: _ViewContext
    private var slots: [Slot]
    var containerHandle: LayoutContainer.Handle?

    init(context: borrowing _ViewContext) {
        self.viewContext = copy context
        self.slots = []
    }

    func collect(into ops: inout LayoutPass, context: inout _CommitContext) {
        if containerHandle == nil { containerHandle = ops.containerHandle }
        var index = 0
        while index < slots.count {
            slots[index].root.collect(into: &ops, &context)

            if slots[index].state == .leaving, slots[index].root.isFullyRemoved {
                var slot = slots.remove(at: index)
                slot.root.unmount(&context)
                continue
            }
            index += 1
        }
    }

    func unmount(_ context: inout _CommitContext) {
        for i in slots.indices { slots[i].root.unmount(&context) }
        slots.removeAll()
    }

    func reportLayoutChange(_ tx: inout _TransactionContext) {
        containerHandle?.reportLayoutChange(&tx)
    }

    var hasLeavingRoots: Bool {
        slots.contains { $0.state == .leaving }
    }

    func appendMounted(key: _ViewKey, node: consuming AnyReconcilable) {
        precondition(slotIndex(for: key) == nil, "duplicate key in MountRootContainer")
        slots.append(.init(key: key, state: .active, root: MountRoot(mounted: node)))
    }

    func createInline<Node: _Reconcilable>(
        key: _ViewKey,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        precondition(slotIndex(for: key) == nil, "duplicate key in MountRootContainer")
        slots.append(makeInlineSlot(key: key, ctx: &ctx, makeNode: makeNode))
    }

    func createScheduled<Node: _Reconcilable>(
        key: _ViewKey,
        transaction: Transaction,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        precondition(slotIndex(for: key) == nil, "duplicate key in MountRootContainer")
        slots.append(makeScheduledSlot(key: key, transaction: transaction, makeNode: makeNode))
    }

    func patch<Node: _Reconcilable>(
        keys newKeys: some BidirectionalCollection<_ViewKey>,
        tx: inout _TransactionContext,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> Node,
        patchNode: (Int, inout Node, inout _TransactionContext) -> Void
    ) {
        assertNoPendingRoots()
        let newKeysArray = Array(newKeys)
        assertNoDuplicateKeys(newKeysArray)

        let oldActiveKeys = activeKeys()
        var didStructureChange = false
        var didReportLayoutChange = false

        if !oldActiveKeys.isEmpty || !newKeysArray.isEmpty {
            let diff = newKeysArray.difference(from: oldActiveKeys).inferringMoves()
            var moversCache: [Int: Slot] = [:]

            for change in diff {
                switch change {
                case let .remove(offset, _, associatedWith: movedTo):
                    let slotIndex = slotIndex(forActiveOffset: offset)
                    if movedTo != nil {
                        var slot = slots.remove(at: slotIndex)
                        slot.root.markMoved(&tx)
                        moversCache[offset] = slot
                    } else {
                        if !didReportLayoutChange {
                            reportLayoutChange(&tx)
                            didReportLayoutChange = true
                        }
                        slots[slotIndex].state = .leaving
                        slots[slotIndex].root.startRemoval(&tx, handle: containerHandle)
                    }
                    didStructureChange = true
                case let .insert(offset, key, associatedWith: movedFrom):
                    var insertionIndex = slotInsertionIndex(forActiveOffset: offset)
                    let slot: Slot

                    if let movedFrom {
                        guard let moved = moversCache.removeValue(forKey: movedFrom) else {
                            preconditionFailure("mover not found in cache")
                        }
                        slot = moved
                    } else if let leavingIndex = leavingSlotIndex(for: key) {
                        if !didReportLayoutChange {
                            reportLayoutChange(&tx)
                            didReportLayoutChange = true
                        }
                        var revived = slots.remove(at: leavingIndex)
                        revived.state = .active
                        revived.root.cancelRemoval(&tx, handle: containerHandle)
                        if leavingIndex < insertionIndex { insertionIndex -= 1 }
                        slot = revived
                    } else {
                        slot = makeScheduledSlot(
                            key: key,
                            transaction: tx.transaction,
                            makeNode: { context, mountCtx in
                                makeNode(offset, context, &mountCtx)
                            }
                        )
                    }

                    slots.insert(slot, at: insertionIndex)
                    didStructureChange = true
                }
            }

            precondition(moversCache.isEmpty, "mover cache is not empty")
        }

        for index in newKeysArray.indices {
            guard let slotIndex = activeSlotIndex(for: newKeysArray[index]) else {
                preconditionFailure("missing active key after patch diff: \(newKeysArray[index])")
            }
            if slots[slotIndex].root.isPending { continue }
            let patched = slots[slotIndex].root.withMountedNode(as: Node.self) { node in
                patchNode(index, &node, &tx)
            }
            precondition(patched, "expected mounted child during keyed patch")
        }

        if didStructureChange, !didReportLayoutChange {
            reportLayoutChange(&tx)
        }
    }

    private func activeKeys() -> [_ViewKey] {
        var keys: [_ViewKey] = []
        keys.reserveCapacity(slots.count)
        for slot in slots where slot.state == .active {
            keys.append(slot.key)
        }
        return keys
    }

    private func slotIndex(forActiveOffset activeOffset: Int) -> Int {
        var activeCount = 0
        for index in slots.indices where slots[index].state == .active {
            if activeCount == activeOffset { return index }
            activeCount += 1
        }
        preconditionFailure("active offset out of range: \(activeOffset)")
    }

    private func slotInsertionIndex(forActiveOffset activeOffset: Int) -> Int {
        var activeCount = 0
        for index in slots.indices {
            if activeCount == activeOffset { return index }
            if slots[index].state == .active {
                activeCount += 1
            }
        }
        precondition(activeCount == activeOffset, "active insertion offset out of range: \(activeOffset)")
        return slots.count
    }

    private func activeSlotIndex(for key: _ViewKey) -> Int? {
        slots.firstIndex { $0.key == key && $0.state == .active }
    }

    private func leavingSlotIndex(for key: _ViewKey) -> Int? {
        slots.firstIndex { $0.key == key && $0.state == .leaving }
    }

    private func slotIndex(for key: _ViewKey) -> Int? {
        slots.firstIndex { $0.key == key }
    }

    private func assertNoPendingRoots() {
        precondition(
            !slots.contains(where: { $0.root.isPending }),
            "double patch of pending MountRoot in MountRootContainer"
        )
    }

    private func assertNoDuplicateKeys(_ keys: [_ViewKey]) {
        var seen: Set<_ViewKey> = []
        seen.reserveCapacity(keys.count)
        for key in keys {
            precondition(seen.insert(key).inserted, "duplicate key in patch: \(key)")
        }
    }

    private func makeInlineSlot<Node: _Reconcilable>(
        key: _ViewKey,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) -> Slot {
        let root = MountRoot(
            eager: viewContext,
            ctx: &ctx,
            create: { context, mountCtx in
                AnyReconcilable(makeNode(context, &mountCtx))
            }
        )
        return .init(key: key, state: .active, root: root)
    }

    private func makeScheduledSlot<Node: _Reconcilable>(
        key: _ViewKey,
        transaction: Transaction,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> Node
    ) -> Slot {
        let root = MountRoot(
            pending: viewContext,
            transaction: transaction,
            create: { context, mountCtx in
                AnyReconcilable(makeNode(context, &mountCtx))
            }
        )
        return .init(key: key, state: .active, root: root)
    }
}
