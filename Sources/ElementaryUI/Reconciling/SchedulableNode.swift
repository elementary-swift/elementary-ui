import BasicContainers
import Reactivity

class SchedulableNode {
    let depthInTree: Int
    /// Created once the node has read anything reactive.
    private var listener: ReactiveTracking.Listener?
    private var scheduler: Scheduler?
    /// Whether the node is queued and hasn't updated since.
    fileprivate var hasPendingUpdate = false

    init(depthInTree: Int) {
        self.depthInTree = depthInTree
    }

    /// Updates the node, whether it was queued or is updated by its parent or an animation.
    final func update(tx: inout _TransactionContext) {
        hasPendingUpdate = false
        performUpdate(tx: &tx)
    }

    /// Only called by ``update(tx:)``.
    func performUpdate(tx: inout _TransactionContext) {}

    func progressAnimation(tx: inout _TransactionContext) -> AnimationProgressResult {
        .completed
    }

    /// Schedules the node whenever `dependencies` change.
    final func startTracking(_ dependencies: consuming ReactiveTracking.AccessedDependencies, scheduler: Scheduler) {
        self.scheduler = scheduler
        // Unretained: the node owns the listener and cancels it when it stops scheduling.
        listener = ReactiveTracking.Listener(
            tracking: dependencies,
            context: Unmanaged.passUnretained(self).toOpaque()
        ) { context in
            let node = Unmanaged<SchedulableNode>.fromOpaque(context).takeUnretainedValue()
            guard let scheduler = node.scheduler else {
                assertionFailure("listener notified after the node stopped scheduling")
                return
            }
            scheduler.invalidateFunction(node)
        }
    }

    /// Runs `body`, and schedules the node whenever anything it read changes.
    final func trackDependencies<T>(scheduler: Scheduler, of body: () -> T) -> T {
        if listener != nil {
            return listener!.track(body)
        }
        var dependencies: ReactiveTracking.AccessedDependencies?
        let value = ReactiveTracking.track(into: &dependencies, body)
        if let dependencies = dependencies.take() {
            startTracking(dependencies, scheduler: scheduler)
        }
        return value
    }

    /// Stops scheduling the node, and drops its pending update.
    final func stopScheduling() {
        hasPendingUpdate = false
        listener.take()?.cancel()
        scheduler = nil
    }
}

struct PendingFunctionQueue: ~Copyable {
    private struct Entry {
        let function: SchedulableNode
        let transaction: Transaction?
    }

    // Sorted by depth in descending order, so the shallowest function is always popped first.
    // Entries of nodes that updated since they were queued are skipped.
    private var functionsToRun = UniqueArray<Entry>()

    var isEmpty: Bool { functionsToRun.isEmpty }

    mutating func enqueue(_ function: SchedulableNode, transaction: Transaction?) {
        guard !function.hasPendingUpdate else { return }
        function.hasPendingUpdate = true
        logTrace("registering function run \(ObjectIdentifier(function))")
        // Insertion from the back: functions mostly arrive at equal or decreasing depth.
        functionsToRun.append(Entry(function: function, transaction: transaction))
        var index = functionsToRun.count - 1
        while index > 0, functionsToRun[index - 1].function.depthInTree < function.depthInTree {
            functionsToRun.swapAt(index, index - 1)
            index -= 1
        }
    }

    mutating func next() -> (SchedulableNode, Transaction?)? {
        while let entry = functionsToRun.popLast() {
            guard entry.function.hasPendingUpdate else { continue }
            return (entry.function, entry.transaction)
        }
        return nil
    }

    deinit {
        assert(functionsToRun.isEmpty, "pending functions dropped without being run")
    }
}
