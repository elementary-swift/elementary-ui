import BasicContainers
import Testing
@testable import ElementaryUI

struct AnyReconcilableStorageTests {
    private final class Counts {
        var destroyed = 0
        var unmounted: [Int] = []
    }

    private struct Small: ~Copyable, _Reconcilable {
        let counts: Counts
        var value: Int
        deinit { counts.destroyed += 1 }
        consuming func unmount(_ context: inout _CommitContext) {
            counts.unmounted.append(value)
        }
    }

    private struct Large: ~Copyable, _Reconcilable {
        let counts: Counts
        var value: Int
        var padding = (0, 0, 0, 0, 0, 0, 0, 0)
        deinit { counts.destroyed += 1 }
        consuming func unmount(_ context: inout _CommitContext) {
            counts.unmounted.append(value)
        }
    }

    @_alignment(16)
    private struct Aligned: ~Copyable, _Reconcilable {
        let counts: Counts
        deinit { counts.destroyed += 1 }
        consuming func unmount(_ context: inout _CommitContext) {
            counts.unmounted.append(16)
        }
    }

    private final class Target {}

    private struct Weak: ~Copyable, _Reconcilable {
        let counts: Counts
        weak var target: Target?
        var value: Int
        deinit { counts.destroyed += 1 }
        consuming func unmount(_ context: inout _CommitContext) {
            counts.unmounted.append(target == nil ? value : -value)
        }
    }

    private func makeContext() -> _CommitContext {
        let dom = TestDOM()
        let scheduler = Scheduler(dom: dom)
        return _CommitContext(dom: dom, scheduler: scheduler, currentFrameTime: 0)
    }

    @Test func inlineMutationAndConsumingUnmount() {
        let counts = Counts()
        var erased = AnyReconcilable(Small(counts: counts, value: 1))
        erased.modify(as: Small.self) { $0.value = 42 }
        var context = makeContext()
        erased.unmount(&context)
        #expect(counts.unmounted == [42])
        #expect(counts.destroyed == 1)
    }

    @Test func heapMutationAndConsumingUnmount() {
        let counts = Counts()
        var erased = AnyReconcilable(Large(counts: counts, value: 1))
        erased.modify(as: Large.self) { $0.value = 42 }
        var context = makeContext()
        erased.unmount(&context)
        #expect(counts.unmounted == [42])
        #expect(counts.destroyed == 1)
    }

    @Test func dropWithoutUnmountDestroysEachPayload() {
        let counts = Counts()
        let small = AnyReconcilable(Small(counts: counts, value: 1))
        let large = AnyReconcilable(Large(counts: counts, value: 2))
        _ = consume small
        _ = consume large
        #expect(counts.unmounted.isEmpty)
        #expect(counts.destroyed == 2)
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
        var context = makeContext()
        while let node = nodes.popLast() { node.unmount(&context) }
        #expect(counts.unmounted == Array((1...128).reversed()))
        #expect(counts.destroyed == 128)
    }

    @Test func overAlignedPayloadUsesHeapStorage() {
        let counts = Counts()
        let node = AnyReconcilable(Aligned(counts: counts))
        var context = makeContext()
        node.unmount(&context)
        #expect(counts.unmounted == [16])
        #expect(counts.destroyed == 1)
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
        var context = makeContext()
        while let node = nodes.popLast() { node.unmount(&context) }
        #expect(counts.unmounted == Array((1...128).reversed()))
        #expect(counts.destroyed == 128)
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
        var context = makeContext()
        while let node = nodes.popLast() { node.unmount(&context) }
        #expect(counts.unmounted == Array((1...128).reversed()))
        #expect(counts.destroyed == 128)
    }
}
