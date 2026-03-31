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

struct KeyedDiffEngine: ~Copyable {
    private var oldKeyMap: [_ViewKey: Int] = [:]

    private var sources: UniqueArray<Int> = .init()
    private var tails: UniqueArray<Int> = .init()
    private var tailIndices: UniqueArray<Int> = .init()
    private var predecessors: UniqueArray<Int> = .init()
    private var inLIS: UniqueArray<Bool> = .init()

    private var activeCells: UniqueArray<MountContainer.Slot?> = .init()
    private var leavingCells: UniqueArray<MountContainer.Slot?> = .init()

    init() {}

    mutating func run(
        activeSlots: inout UniqueArray<MountContainer.Slot>,
        leavingSlots: inout UniqueArray<MountContainer.Slot>,
        leavingByKey: inout [_ViewKey: Int],
        removedNodes: inout UniqueArray<MountContainer.RemovedNode>,
        keys: borrowing Span<_ViewKey>,
        tx: inout _TransactionContext,
        containerHandle: LayoutContainer.Handle?
    ) -> Bool {
        let oldCount = activeSlots.count
        let newCount = keys.count
        if oldCount == 0 && newCount == 0 { return false }

        let (prefixCount, suffixCount) = scanUnchangedEdges(activeSlots: activeSlots, keys: keys)
        let oldMiddleStart = prefixCount
        let oldMiddleEnd = oldCount - suffixCount
        let newMiddleStart = prefixCount
        let newMiddleEnd = newCount - suffixCount
        let oldMiddleCount = oldMiddleEnd - oldMiddleStart
        let newMiddleCount = newMiddleEnd - newMiddleStart

        if oldMiddleCount == 0 && newMiddleCount == 0 {
            return false
        }

        prepareScratch(
            oldActiveCount: oldCount,
            oldMiddleCount: oldMiddleCount,
            newMiddleCount: newMiddleCount,
            oldLeavingCount: leavingSlots.count
        )

        var didStructureChange = false
        buildSourcePlan(
            activeSlots: activeSlots,
            keys: keys,
            leavingByKey: leavingByKey,
            oldMiddleStart: oldMiddleStart,
            oldMiddleEnd: oldMiddleEnd,
            newMiddleStart: newMiddleStart,
            newMiddleEnd: newMiddleEnd,
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
            oldCount: oldCount,
            prefixCount: prefixCount,
            suffixCount: suffixCount,
            newMiddleStart: newMiddleStart,
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

    private mutating func prepareScratch(
        oldActiveCount: Int,
        oldMiddleCount: Int,
        newMiddleCount: Int,
        oldLeavingCount: Int
    ) {
        oldKeyMap.removeAll(keepingCapacity: true)
        oldKeyMap.reserveCapacity(oldMiddleCount)

        sources.removeAll(keepingCapacity: true)
        sources.reserveCapacity(newMiddleCount)

        tails.removeAll(keepingCapacity: true)
        tails.reserveCapacity(newMiddleCount)

        tailIndices.removeAll(keepingCapacity: true)
        tailIndices.reserveCapacity(newMiddleCount)

        predecessors.removeAll(keepingCapacity: true)
        predecessors.reserveCapacity(newMiddleCount)

        inLIS.removeAll(keepingCapacity: true)
        inLIS.reserveCapacity(newMiddleCount)

        activeCells.removeAll(keepingCapacity: true)
        activeCells.reserveCapacity(oldActiveCount)
        for _ in 0..<oldActiveCount {
            activeCells.append(nil)
        }

        leavingCells.removeAll(keepingCapacity: true)
        leavingCells.reserveCapacity(oldLeavingCount)
        for _ in 0..<oldLeavingCount {
            leavingCells.append(nil)
        }
    }

    private mutating func buildSourcePlan(
        activeSlots: borrowing UniqueArray<MountContainer.Slot>,
        keys: borrowing Span<_ViewKey>,
        leavingByKey: borrowing [_ViewKey: Int],
        oldMiddleStart: Int,
        oldMiddleEnd: Int,
        newMiddleStart: Int,
        newMiddleEnd: Int,
        didStructureChange: inout Bool
    ) {
        let oldSlots = activeSlots.span
        for oldIndex in oldMiddleStart..<oldMiddleEnd {
            oldKeyMap[oldSlots[unchecked: oldIndex].key] = oldIndex
        }

        for newIndex in newMiddleStart..<newMiddleEnd {
            let key = keys[unchecked: newIndex]
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
        var oldIndex = activeSlots.count
        while oldIndex > 0 {
            oldIndex -= 1
            activeCells[oldIndex] = activeSlots.removeLast()
        }

        var leavingIndex = leavingSlots.count
        while leavingIndex > 0 {
            leavingIndex -= 1
            leavingCells[leavingIndex] = leavingSlots.removeLast()
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
            var slot = takeActiveCell(at: removedOldIndex)
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

        for _ in 0..<sourceCount {
            predecessors.append(-1)
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
                var slot = takeActiveCell(at: source)
                slot.markMovedInActiveLane()
                activeCells[source] = .some(consume slot)
                didMove = true
            }
        }

        return didMove
    }

    private mutating func rebuildActive(
        oldCount: Int,
        prefixCount: Int,
        suffixCount: Int,
        newMiddleStart: Int,
        keys: borrowing Span<_ViewKey>,
        tx: inout _TransactionContext,
        containerHandle: LayoutContainer.Handle?
    ) -> UniqueArray<MountContainer.Slot> {
        var rebuiltActive = UniqueArray<MountContainer.Slot>(capacity: keys.count)

        if prefixCount > 0 {
            for oldIndex in 0..<prefixCount {
                rebuiltActive.append(takeActiveCell(at: oldIndex))
            }
        }

        var middleOffset = 0
        while middleOffset < sources.count {
            let source = sources[middleOffset]
            let newIndex = newMiddleStart + middleOffset

            if source >= 0 {
                rebuiltActive.append(takeActiveCell(at: source))
            } else if source == _KeyedDiffSource.new {
                rebuiltActive.append(
                    .pending(key: keys[unchecked: newIndex], transaction: tx.transaction, newKeyIndex: newIndex)
                )
            } else {
                let leavingIndex = _KeyedDiffSource.decodeRevive(source)
                if leavingIndex >= 0 && leavingIndex < leavingCells.count, var revived = leavingCells[leavingIndex].take() {
                    revived.reviveFromLeaving(tx: &tx, handle: containerHandle)
                    rebuiltActive.append(revived)
                } else {
                    rebuiltActive.append(
                        .pending(key: keys[unchecked: newIndex], transaction: tx.transaction, newKeyIndex: newIndex)
                    )
                }
            }

            middleOffset += 1
        }

        if suffixCount > 0 {
            let oldSuffixStart = oldCount - suffixCount
            for oldIndex in oldSuffixStart..<oldCount {
                rebuiltActive.append(takeActiveCell(at: oldIndex))
            }
        }

        return rebuiltActive
    }

    private mutating func appendRemainingLeavingSlots(
        into rebuiltLeaving: inout UniqueArray<MountContainer.Slot>
    ) {
        var cells = leavingCells.mutableSpan
        for index in cells.indices {
            if let slot = cells[unchecked: index].take() {
                rebuiltLeaving.append(slot)
            }
        }
    }

    private func scanUnchangedEdges(
        activeSlots: borrowing UniqueArray<MountContainer.Slot>,
        keys: borrowing Span<_ViewKey>
    ) -> (prefixCount: Int, suffixCount: Int) {
        let oldCount = activeSlots.count
        let newCount = keys.count
        let sharedCount = Swift.min(oldCount, newCount)

        let oldSlots = activeSlots.span

        var prefixCount = 0
        while prefixCount < sharedCount {
            if oldSlots[unchecked: prefixCount].key != keys[unchecked: prefixCount] {
                break
            }
            prefixCount += 1
        }

        var suffixCount = 0
        let maxSuffix = sharedCount - prefixCount
        while suffixCount < maxSuffix {
            let oldIndex = oldCount - 1 - suffixCount
            let newIndex = newCount - 1 - suffixCount
            if oldSlots[unchecked: oldIndex].key != keys[unchecked: newIndex] {
                break
            }
            suffixCount += 1
        }

        return (prefixCount, suffixCount)
    }

    @inline(__always)
    private mutating func takeActiveCell(at index: Int) -> MountContainer.Slot {
        guard let slot = activeCells[index].take() else {
            fatalError("slot was already consumed")
        }
        return slot
    }

    private func rebuildLeavingMap(
        leavingByKey: inout [_ViewKey: Int],
        leavingSlots: borrowing UniqueArray<MountContainer.Slot>
    ) {
        leavingByKey.removeAll(keepingCapacity: true)
        leavingByKey.reserveCapacity(leavingSlots.count)

        let slots = leavingSlots.span
        for index in slots.indices {
            leavingByKey[slots[unchecked: index].key] = index
        }
    }
}
