import Testing

@testable import ElementaryUI

struct DependentsTests {
    @Test func removesInAnyOrderAndReusesVacancies() {
        let log = InvalidationLog()
        let source = DependencyNode()
        let dependents = (0..<8).map { Dependent($0, log) }
        let positions = dependents[0..<6].map { source.dependents.add($0) }

        for index in [3, 2, 5, 4] {
            source.dependents.remove(at: positions[index])
        }
        #expect(invalidated(by: source, log) == [0, 1])

        // The most recent vacancy is taken first.
        let later = dependents[6..<8].map { source.dependents.add($0) }
        #expect(later == [positions[4], positions[5]])
        #expect(invalidated(by: source, log) == [0, 1, 6, 7])
    }

    @Test func refillsTheFirstPositionAndStartsOverWhenEmpty() {
        let log = InvalidationLog()
        let source = DependencyNode()
        let dependents = (0..<6).map { Dependent($0, log) }
        let positions = dependents[0..<3].map { source.dependents.add($0) }

        source.dependents.remove(at: positions[0])
        #expect(invalidated(by: source, log) == [1, 2])

        let refilled = source.dependents.add(dependents[3])
        #expect(refilled == positions[0])
        #expect(invalidated(by: source, log) == [3, 1, 2])

        for position in [positions[2], refilled, positions[1]] {
            source.dependents.remove(at: position)
        }
        let isEmpty = source.dependents.isEmpty
        #expect(isEmpty)
        #expect(invalidated(by: source, log) == [])

        let again = dependents[4..<6].map { source.dependents.add($0) }
        #expect(again == Array(positions[0..<2]))
        #expect(invalidated(by: source, log) == [4, 5])
    }

    private func invalidated(by source: DependencyNode, _ log: InvalidationLog) -> [Int] {
        log.ids = []
        var context = _TransactionContext(scheduler: Scheduler(dom: TestDOM()), currentTime: 0)
        source.dependents.invalidateAll(&context)
        context.drain()
        return log.ids
    }
}

private final class InvalidationLog {
    var ids: [Int] = []
}

private final class Dependent: DependencyNode {
    let id: Int
    let log: InvalidationLog

    init(_ id: Int, _ log: InvalidationLog) {
        self.id = id
        self.log = log
    }

    override func invalidate(_ context: inout _TransactionContext) {
        log.ids.append(id)
    }
}
