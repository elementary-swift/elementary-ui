import Testing

@testable import ElementaryUI

struct DependencyTrackerTests {
    @Test func compactsAndKeepsWorkingAfterManyRemovals() {
        let log = InvalidationLog()
        let dependents = (0..<100).map { Dependent($0, log) }
        var tracker = DependencyTracker()
        for dependent in dependents { tracker.addDependency(dependent) }

        // Registration order, as slots unmount, then a few out of order.
        for dependent in dependents[0..<60] { tracker.removeDependency(dependent) }
        tracker.removeDependency(dependents[99])
        tracker.removeDependency(dependents[70])
        tracker.addDependency(dependents[0])
        invalidate(tracker)

        #expect(log.ids == Array(60..<70) + Array(71..<99) + [0])
    }

    private func invalidate(_ tracker: borrowing DependencyTracker) {
        var context = _TransactionContext(scheduler: Scheduler(dom: TestDOM()), currentTime: 0)
        tracker.invalidateAll(&context)
        context.drain()
    }
}

private final class InvalidationLog {
    var ids: [Int] = []
}

private final class Dependent: Invalidateable {
    let id: Int
    let log: InvalidationLog

    init(_ id: Int, _ log: InvalidationLog) {
        self.id = id
        self.log = log
    }

    func invalidate(_ context: inout _TransactionContext) {
        log.ids.append(id)
    }
}
