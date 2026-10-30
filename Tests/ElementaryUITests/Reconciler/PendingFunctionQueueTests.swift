import Testing

@testable import ElementaryUI

struct PendingFunctionQueueTests {
    @Test func functionsRunInTheTransactionTheyWereQueuedUnder() {
        let plain = TransactionProbe()
        let animated = TransactionProbe()

        var queue = PendingFunctionQueue()
        queue.enqueue(plain)

        var context = _TransactionContext(
            scheduler: Scheduler(dom: TestDOM()),
            currentTime: 0,
            pendingFunctions: consume queue
        )
        context.withModifiedTransaction({ $0.animation = .default }) { $0.addFunction(animated) }
        context.drain()

        #expect(plain.didRunAnimated == false)
        #expect(animated.didRunAnimated == true)
    }
}

private final class TransactionProbe: SchedulableNode {
    var didRunAnimated: Bool?

    init() {
        super.init(depthInTree: 0)
    }

    override func performUpdate(tx: inout _TransactionContext) {
        didRunAnimated = tx.transaction.animation != nil
    }
}
