import Testing

@testable import ElementaryUI

struct DependencyNodeTests {
    @Test func removesInAnyOrderAndReusesVacancies() {
        let log = InvalidationLog()
        let source = DependencyNode()
        let dependents = (0..<10).map { Dependent($0, log) }
        for dependent in dependents[0..<6] {
            dependent.attach(to: source)
        }

        for index in [3, 2, 5, 4] {
            dependents[index].removeDependency()
        }
        #expect(invalidated(by: source, log) == [0, 1])

        // The most recent vacancy is taken first.
        for dependent in dependents[6..<10] {
            dependent.attach(to: source)
        }
        #expect(invalidated(by: source, log) == [0, 1, 8, 9, 6, 7])
    }

    @Test func refillsTheFirstPosition() {
        let log = InvalidationLog()
        let source = DependencyNode()
        let dependents = (0..<6).map { Dependent($0, log) }
        for dependent in dependents[0..<3] {
            dependent.attach(to: source)
        }

        dependents[0].removeDependency()
        #expect(invalidated(by: source, log) == [1, 2])

        dependents[3].attach(to: source)
        #expect(invalidated(by: source, log) == [3, 1, 2])

        for index in [2, 3, 1] {
            dependents[index].removeDependency()
        }
        #expect(invalidated(by: source, log) == [])

        for dependent in dependents[4..<6] {
            dependent.attach(to: source)
        }
        #expect(invalidated(by: source, log) == [4, 5])
    }

    private func invalidated(by source: DependencyNode, _ log: InvalidationLog) -> [Int] {
        log.ids = []
        var context = _TransactionContext(scheduler: Scheduler(dom: TestDOM()), currentTime: 0)
        source.invalidateDependents(&context)
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
    private var dependency: Dependency?

    init(_ id: Int, _ log: InvalidationLog) {
        self.id = id
        self.log = log
    }

    func attach(to source: DependencyNode) {
        dependency = addDependency(on: source)
    }

    func removeDependency() {
        dependency.take()!.remove()
    }

    override func invalidate(_ context: inout _TransactionContext) {
        log.ids.append(id)
    }
}
