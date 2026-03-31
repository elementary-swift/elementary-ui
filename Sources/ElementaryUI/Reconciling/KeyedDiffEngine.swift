import BasicContainers

enum _KeyedDiffSource {
    static let new = -1
    private static let reviveBase = -2

    @inline(__always)
    static func encodeRevive(_ leavingIndex: Int) -> Int {
        reviveBase - leavingIndex
    }

    @inline(__always)
    static func isRevive(_ source: Int) -> Bool {
        source <= reviveBase
    }

    @inline(__always)
    static func decodeRevive(_ source: Int) -> Int {
        reviveBase - source
    }
}

enum _KeyedSlotCell: ~Copyable {
    case available(MountContainer.Slot)
    case empty

    var isAvailable: Bool {
        borrowing get {
            switch self {
            case .available:
                true
            case .empty:
                false
            }
        }
    }

    mutating func store(_ slot: consuming MountContainer.Slot) {
        self = .available(slot)
    }

    mutating func take() -> MountContainer.Slot {
        switch consume self {
        case .available(let slot):
            self = .empty
            return slot
        case .empty:
            fatalError("slot was already consumed")
        }
    }
}

struct KeyedDiffEngine: ~Copyable {
    private var oldKeyMap: [_ViewKey: Int] = [:]

    private var sources: UniqueArray<Int> = .init()
    private var tails: UniqueArray<Int> = .init()
    private var tailIndices: UniqueArray<Int> = .init()
    private var predecessors: UniqueArray<Int> = .init()
    private var inLIS: UniqueArray<Bool> = .init()

    private var activeCells: UniqueArray<_KeyedSlotCell> = .init()
    private var leavingCells: UniqueArray<_KeyedSlotCell> = .init()

    init() {}

    mutating func run(
        activeSlots: inout UniqueArray<MountContainer.Slot>,
        leavingSlots: inout UniqueArray<MountContainer.Slot>,
        leavingByKey: inout [_ViewKey: Int],
        removedNodes: inout UniqueArray<MountContainer.RemovedNode>,
        keys: borrowing UniqueArray<_ViewKey>,
        tx: inout _TransactionContext,
        containerHandle: LayoutContainer.Handle?
    ) -> Bool {
        let oldCount = activeSlots.count
        let newCount = keys.count
        if oldCount == 0 && newCount == 0 { return false }

        var didStructureChange = false
        buildSourcePlan(
            activeSlots: activeSlots,
            keys: keys,
            leavingByKey: leavingByKey,
            didStructureChange: &didStructureChange
        )
        materializeCells(activeSlots: &activeSlots, leavingSlots: &leavingSlots)

        var rebuiltLeaving = UniqueArray<MountContainer.Slot>(capacity: leavingCells.count + oldKeyMap.count)
        processRemovedActiveSlots(
            tx: &tx,
            containerHandle: containerHandle,
            rebuiltLeaving: &rebuiltLeaving,
            removedNodes: &removedNodes,
            didStructureChange: &didStructureChange
        )

        if markMovedByLIS() {
            didStructureChange = true
        }

        let rebuiltActive = rebuildActive(
            keys: keys,
            tx: &tx,
            containerHandle: containerHandle
        )
        appendRemainingLeavingSlots(into: &rebuiltLeaving)
        rebuildLeavingMap(leavingByKey: &leavingByKey, leavingSlots: rebuiltLeaving)

        activeSlots = consume rebuiltActive
        leavingSlots = consume rebuiltLeaving
        return didStructureChange
    }

    private mutating func buildSourcePlan(
        activeSlots: borrowing UniqueArray<MountContainer.Slot>,
        keys: borrowing UniqueArray<_ViewKey>,
        leavingByKey: borrowing [_ViewKey: Int],
        didStructureChange: inout Bool
    ) {
        oldKeyMap.removeAll(keepingCapacity: true)
        oldKeyMap.reserveCapacity(activeSlots.count)
        for oldIndex in activeSlots.indices {
            oldKeyMap[activeSlots[oldIndex].key] = oldIndex
        }

        sources.removeAll(keepingCapacity: true)
        sources.reserveCapacity(keys.count)
        for newIndex in keys.indices {
            let key = keys[newIndex]
            if let oldIndex = oldKeyMap.removeValue(forKey: key) {
                sources.append(oldIndex)
            } else if let leavingIndex = leavingByKey[key] {
                sources.append(_KeyedDiffSource.encodeRevive(leavingIndex))
                didStructureChange = true
            } else {
                sources.append(_KeyedDiffSource.new)
                didStructureChange = true
            }
        }
    }

    private mutating func materializeCells(
        activeSlots: inout UniqueArray<MountContainer.Slot>,
        leavingSlots: inout UniqueArray<MountContainer.Slot>
    ) {
        let oldCount = activeSlots.count
        activeCells.removeAll(keepingCapacity: true)
        activeCells.reserveCapacity(oldCount)
        for _ in 0..<oldCount {
            activeCells.append(.empty)
        }

        var oldIndex = oldCount
        while oldIndex > 0 {
            oldIndex -= 1
            activeCells[oldIndex].store(activeSlots.removeLast())
        }

        let oldLeavingCount = leavingSlots.count
        leavingCells.removeAll(keepingCapacity: true)
        leavingCells.reserveCapacity(oldLeavingCount)
        for _ in 0..<oldLeavingCount {
            leavingCells.append(.empty)
        }

        var leavingIndex = oldLeavingCount
        while leavingIndex > 0 {
            leavingIndex -= 1
            leavingCells[leavingIndex].store(leavingSlots.removeLast())
        }
    }

    private mutating func processRemovedActiveSlots(
        tx: inout _TransactionContext,
        containerHandle: LayoutContainer.Handle?,
        rebuiltLeaving: inout UniqueArray<MountContainer.Slot>,
        removedNodes: inout UniqueArray<MountContainer.RemovedNode>,
        didStructureChange: inout Bool
    ) {
        for (_, removedOldIndex) in oldKeyMap {
            var slot = activeCells[removedOldIndex].take()
            switch slot.beginRemovalForDiff(tx: &tx, handle: containerHandle) {
            case .none:
                break
            case .removed(let removed):
                removedNodes.append(removed)
                didStructureChange = true
            case .leaving(let leavingSlot):
                rebuiltLeaving.append(leavingSlot)
                didStructureChange = true
            }
        }
    }

    private mutating func markMovedByLIS() -> Bool {
        let sourceCount = sources.count
        guard sourceCount > 0 else { return false }

        tails.removeAll(keepingCapacity: true)
        tails.reserveCapacity(sourceCount)

        tailIndices.removeAll(keepingCapacity: true)
        tailIndices.reserveCapacity(sourceCount)

        predecessors.removeAll(keepingCapacity: true)
        predecessors.reserveCapacity(sourceCount)
        for _ in 0..<sourceCount {
            predecessors.append(-1)
        }

        inLIS.removeAll(keepingCapacity: true)
        inLIS.reserveCapacity(sourceCount)
        for _ in 0..<sourceCount {
            inLIS.append(false)
        }

        for sourceIndex in sources.indices {
            let source = sources[sourceIndex]
            guard source >= 0 else { continue }

            var low = 0
            var high = tails.count
            while low < high {
                let mid = (low + high) &>> 1
                if tails[mid] < source {
                    low = mid + 1
                } else {
                    high = mid
                }
            }

            if low == tails.count {
                tails.append(source)
                tailIndices.append(sourceIndex)
            } else {
                tails[low] = source
                tailIndices[low] = sourceIndex
            }

            predecessors[sourceIndex] = low > 0 ? tailIndices[low - 1] : -1
        }

        if !tails.isEmpty {
            var lisPosition = tailIndices[tails.count - 1]
            while lisPosition >= 0 {
                inLIS[lisPosition] = true
                lisPosition = predecessors[lisPosition]
            }
        }

        var didMove = false
        for sourceIndex in sources.indices {
            let source = sources[sourceIndex]
            if source >= 0 && !inLIS[sourceIndex] {
                var slot = activeCells[source].take()
                slot.markMovedInActiveLane()
                activeCells[source].store(slot)
                didMove = true
            }
        }

        return didMove
    }

    private mutating func rebuildActive(
        keys: borrowing UniqueArray<_ViewKey>,
        tx: inout _TransactionContext,
        containerHandle: LayoutContainer.Handle?
    ) -> UniqueArray<MountContainer.Slot> {
        var rebuiltActive = UniqueArray<MountContainer.Slot>(capacity: keys.count)

        for newIndex in keys.indices {
            let source = sources[newIndex]
            if source >= 0 {
                rebuiltActive.append(activeCells[source].take())
            } else if source == _KeyedDiffSource.new {
                rebuiltActive.append(
                    .pending(key: keys[newIndex], transaction: tx.transaction, newKeyIndex: newIndex)
                )
            } else if _KeyedDiffSource.isRevive(source) {
                let leavingIndex = _KeyedDiffSource.decodeRevive(source)
                if leavingIndex >= 0 && leavingIndex < leavingCells.count && leavingCells[leavingIndex].isAvailable {
                    var revived = leavingCells[leavingIndex].take()
                    revived.reviveFromLeaving(tx: &tx, handle: containerHandle)
                    rebuiltActive.append(revived)
                } else {
                    rebuiltActive.append(
                        .pending(key: keys[newIndex], transaction: tx.transaction, newKeyIndex: newIndex)
                    )
                }
            } else {
                rebuiltActive.append(
                    .pending(key: keys[newIndex], transaction: tx.transaction, newKeyIndex: newIndex)
                )
            }
        }

        return rebuiltActive
    }

    private mutating func appendRemainingLeavingSlots(
        into rebuiltLeaving: inout UniqueArray<MountContainer.Slot>
    ) {
        for index in leavingCells.indices {
            if leavingCells[index].isAvailable {
                rebuiltLeaving.append(leavingCells[index].take())
            }
        }
    }

    private func rebuildLeavingMap(
        leavingByKey: inout [_ViewKey: Int],
        leavingSlots: borrowing UniqueArray<MountContainer.Slot>
    ) {
        leavingByKey.removeAll(keepingCapacity: true)
        leavingByKey.reserveCapacity(leavingSlots.count)
        for index in leavingSlots.indices {
            leavingByKey[leavingSlots[index].key] = index
        }
    }
}
