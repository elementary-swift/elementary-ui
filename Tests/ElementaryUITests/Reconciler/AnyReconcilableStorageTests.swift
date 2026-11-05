import BasicContainers
import Testing
@testable import ElementaryUI

struct AnyReconcilableStorageTests {
    private final class Counts {
        var destroyed: [Int] = []
    }

    private struct Small: ~Copyable {
        let counts: Counts
        var value: Int
        deinit { counts.destroyed.append(value) }
    }

    private struct Large: ~Copyable {
        let counts: Counts
        var value: Int
        var padding = (0, 0, 0, 0, 0, 0, 0, 0)
        deinit { counts.destroyed.append(value) }
    }

    @_alignment(16)
    private struct Aligned: ~Copyable {
        let counts: Counts
        deinit { counts.destroyed.append(16) }
    }

    private final class Target {}

    private struct Weak: ~Copyable {
        let counts: Counts
        weak var target: Target?
        var value: Int
        deinit { counts.destroyed.append(target == nil ? value : -value) }
    }

    @Test func inlineMutationAndDrop() {
        let counts = Counts()
        var erased = AnyReconcilable(Small(counts: counts, value: 1))
        erased.modify(as: Small.self) { $0.value = 42 }
        _ = consume erased
        #expect(counts.destroyed == [42])
            }

    @Test func heapMutationAndDrop() {
        let counts = Counts()
        var erased = AnyReconcilable(Large(counts: counts, value: 1))
        erased.modify(as: Large.self) { $0.value = 42 }
        _ = consume erased
        #expect(counts.destroyed == [42])
            }

    @Test func dropDestroysEachPayload() {
        let counts = Counts()
        let small = AnyReconcilable(Small(counts: counts, value: 1))
        let large = AnyReconcilable(Large(counts: counts, value: 2))
        _ = consume small
        _ = consume large
        #expect(counts.destroyed == [1, 2])
    }

    @Test func arrayRelocationPreservesUniqueOwnership() {
        let counts = Counts()
        var nodes = UniqueArray<AnyReconcilable>()
        for value in 0..<128 {
            nodes.append(AnyReconcilable(Small(counts: counts, value: value)))
        }
        for index in nodes.indices {
            nodes[index].modify(as: Small.self) { $0.value += 1 }
        }
        while let node = nodes.popLast() { _ = consume node }
        #expect(counts.destroyed == Array((1...128).reversed()))
            }

    @Test func overAlignedPayloadUsesHeapStorage() {
        let counts = Counts()
        let node = AnyReconcilable(Aligned(counts: counts))
        _ = consume node
        #expect(counts.destroyed == [16])
            }

    @Test func smallWeakPayloadSurvivesRelocationAndZeroing() {
        #expect(MemoryLayout<Weak>.size <= MemoryLayout<_TextNode>.stride)
        let counts = Counts()
        var target: Target? = Target()
        var nodes = UniqueArray<AnyReconcilable>()
        for value in 0..<128 {
            nodes.append(AnyReconcilable(Weak(counts: counts, target: target, value: value)))
        }
        nodes[0].modify(as: Weak.self) { #expect($0.target === target) }
        target = nil
        for index in nodes.indices {
            nodes[index].modify(as: Weak.self) {
                #expect($0.target == nil)
                $0.value += 1
            }
        }
        while let node = nodes.popLast() { _ = consume node }
        #expect(counts.destroyed == Array((1...128).reversed()))
            }

    @Test func mixedInlineAndHeapRelocationPreservesOwnership() {
        let counts = Counts()
        var nodes = UniqueArray<AnyReconcilable>()
        for value in 0..<128 {
            if value.isMultiple(of: 2) {
                nodes.append(AnyReconcilable(Small(counts: counts, value: value)))
            } else {
                nodes.append(AnyReconcilable(Large(counts: counts, value: value)))
            }
        }
        for index in nodes.indices {
            if index.isMultiple(of: 2) {
                nodes[index].modify(as: Small.self) { $0.value += 1 }
            } else {
                nodes[index].modify(as: Large.self) { $0.value += 1 }
            }
        }
        while let node = nodes.popLast() { _ = consume node }
        #expect(counts.destroyed == Array((1...128).reversed()))
            }
}
