import BasicContainers
import ContainersPreview
import Synchronization

struct KeyedDiffEngine: ~Copyable {
    private var oldKeyMap: [_ViewKey: Int] = [:]
    private var leavingKeyMap: [_ViewKey: Int] = [:]

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
        removedSlots: inout UniqueArray<MountContainer.Slot>,
        keys: borrowing Span<_ViewKey>,
        transaction: Transaction
    ) -> Bool {
        let oldCount = activeSlots.count
        let newCount = keys.count
        if oldCount == 0 && newCount == 0 { return false }

        let (prefixCount, suffixCount) = scanUnchangedEdges(activeSlots: activeSlots.span, keys: keys)
        let oldMiddleCount = oldCount - prefixCount - suffixCount
        let newMiddleCount = newCount - prefixCount - suffixCount

        if oldMiddleCount == 0 && newMiddleCount == 0 {
            return false
        }

        prepareScratch(
            oldMiddleCount: oldMiddleCount,
            newMiddleCount: newMiddleCount,
            oldLeavingCount: leavingSlots.count
        )

        buildLeavingKeyMap(leavingSlots: leavingSlots.span)
        materializeLeavingCells(leavingSlots: &leavingSlots)

        let newMiddleKeys = keys.extracting(prefixCount..<(prefixCount + newMiddleCount))

        var didStructureChange = false
        buildSourcePlan(
            oldMiddleSlots: activeSlots.span.extracting(prefixCount..<(prefixCount + oldMiddleCount)),
            newMiddleKeys: newMiddleKeys,
            didStructureChange: &didStructureChange
        )

        activeSlots.replace(
            removing: prefixCount..<(prefixCount + oldMiddleCount),
            consumingWith: { inputSpan in
                let count = inputSpan.count
                for i in 0..<count {
                    self.activeCells[i] = .some(inputSpan.removeFirst())
                }
            },
            addingCount: newMiddleCount,
            initializingWith: { outputSpan in
                if self.markMovedByLIS() { didStructureChange = true }

                for middleOffset in 0..<self.sources.count {
                    let source = self.sources[middleOffset]
                    if source >= 0 {
                        outputSpan.append(self.takeActiveCell(at: source))
                    } else if source == KeyedDiffSource.new {
                        outputSpan.append(
                            .pending(
                                key: newMiddleKeys[unchecked: middleOffset],
                                transaction: transaction,
                                newKeyIndex: prefixCount + middleOffset
                            )
                        )
                    } else {
                        let leavingIndex = KeyedDiffSource.decodeRevive(source)
                        if leavingIndex >= 0 && leavingIndex < self.leavingCells.count,
                            var revived = self.leavingCells[leavingIndex].take()
                        {
                            revived.markReviving()
                            outputSpan.append(revived)
                        } else {
                            outputSpan.append(
                                .pending(
                                    key: newMiddleKeys[unchecked: middleOffset],
                                    transaction: transaction,
                                    newKeyIndex: prefixCount + middleOffset
                                )
                            )
                        }
                    }
                }
            }
        )

        collectRemovedSlots(into: &removedSlots)
        if !oldKeyMap.isEmpty { didStructureChange = true }
        drainUnconsumedLeavingCells(into: &leavingSlots)
        return didStructureChange
    }

    private mutating func prepareScratch(
        oldMiddleCount: Int,
        newMiddleCount: Int,
        oldLeavingCount: Int
    ) {
        oldKeyMap.removeAll(keepingCapacity: true)
        oldKeyMap.reserveCapacity(oldMiddleCount)

        leavingKeyMap.removeAll(keepingCapacity: true)
        leavingKeyMap.reserveCapacity(oldLeavingCount)

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
        activeCells.reserveCapacity(oldMiddleCount)
        for _ in 0..<oldMiddleCount {
            activeCells.append(nil)
        }

        leavingCells.removeAll(keepingCapacity: true)
        leavingCells.reserveCapacity(oldLeavingCount)
        for _ in 0..<oldLeavingCount {
            leavingCells.append(nil)
        }
    }

    private mutating func buildSourcePlan(
        oldMiddleSlots: borrowing Span<MountContainer.Slot>,
        newMiddleKeys: borrowing Span<_ViewKey>,
        didStructureChange: inout Bool
    ) {
        for i in oldMiddleSlots.indices {
            oldKeyMap[oldMiddleSlots[unchecked: i].key] = i
        }

        for i in newMiddleKeys.indices {
            let key = newMiddleKeys[unchecked: i]
            if let oldIndex = oldKeyMap.removeValue(forKey: key) {
                sources.append(oldIndex)
            } else if let leavingIndex = leavingKeyMap[key] {
                sources.append(KeyedDiffSource.encodeRevive(leavingIndex))
                didStructureChange = true
            } else {
                sources.append(KeyedDiffSource.new)
                didStructureChange = true
            }
        }
    }

    private mutating func materializeLeavingCells(
        leavingSlots: inout UniqueArray<MountContainer.Slot>
    ) {
        var i = leavingSlots.count
        while i > 0 {
            i -= 1
            leavingCells[i] = leavingSlots.removeLast()
        }
    }

    private mutating func buildLeavingKeyMap(
        leavingSlots: borrowing Span<MountContainer.Slot>
    ) {
        for i in leavingSlots.indices {
            leavingKeyMap[leavingSlots[unchecked: i].key] = i
        }
    }

    private mutating func collectRemovedSlots(
        into removedSlots: inout UniqueArray<MountContainer.Slot>
    ) {
        for (_, removedOldIndex) in oldKeyMap {
            removedSlots.append(takeActiveCell(at: removedOldIndex))
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

    private mutating func drainUnconsumedLeavingCells(
        into leavingSlots: inout UniqueArray<MountContainer.Slot>
    ) {
        var cells = leavingCells.mutableSpan
        for index in cells.indices {
            if let slot = cells[unchecked: index].take() {
                leavingSlots.append(slot)
            }
        }
    }

    private func scanUnchangedEdges(
        activeSlots: borrowing Span<MountContainer.Slot>,
        keys: borrowing Span<_ViewKey>
    ) -> (prefixCount: Int, suffixCount: Int) {
        let oldCount = activeSlots.count
        let newCount = keys.count
        let sharedCount = Swift.min(oldCount, newCount)

        var prefixCount = 0
        while prefixCount < sharedCount {
            if activeSlots[unchecked: prefixCount].key != keys[unchecked: prefixCount] {
                break
            }
            prefixCount += 1
        }

        var suffixCount = 0
        let maxSuffix = sharedCount - prefixCount
        while suffixCount < maxSuffix {
            let oldIndex = oldCount - 1 - suffixCount
            let newIndex = newCount - 1 - suffixCount
            if activeSlots[unchecked: oldIndex].key != keys[unchecked: newIndex] {
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

}

private enum KeyedDiffSource {
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
