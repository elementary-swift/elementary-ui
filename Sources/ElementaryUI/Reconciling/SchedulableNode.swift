import Reactivity

class SchedulableNode {
    let depthInTree: Int
    /// Created once the node has read anything reactive.
    private var listener: ReactiveTracking.Listener?
    private var scheduler: Scheduler?
    /// Set by the first change after a render, so the node is queued once per render.
    private var isInvalidated = false

    init(depthInTree: Int) {
        self.depthInTree = depthInTree
    }

    func runUpdate(tx: inout _TransactionContext) {}

    func progressAnimation(tx: inout _TransactionContext) -> AnimationProgressResult {
        .completed
    }

    /// Marks the node as needing a re-run; returns `false` if it already was.
    final func markInvalidated() -> Bool {
        guard !isInvalidated else { return false }
        isInvalidated = true
        return true
    }

    /// Runs a queued update, unless a render since the invalidation already handled it.
    final func runInvalidatedUpdate(tx: inout _TransactionContext) {
        guard isInvalidated else { return }
        runUpdate(tx: &tx)
    }

    /// Schedules the node whenever `dependencies` change.
    final func startTracking(_ dependencies: consuming ReactiveTracking.AccessedDependencies, scheduler: Scheduler) {
        self.scheduler = scheduler
        // Unretained: the node owns the listener and cancels it when it stops tracking.
        listener = ReactiveTracking.Listener(
            tracking: dependencies,
            context: Unmanaged.passUnretained(self).toOpaque()
        ) { context in
            let node = Unmanaged<SchedulableNode>.fromOpaque(context).takeUnretainedValue()
            guard let scheduler = node.scheduler else {
                assertionFailure("listener notified after the node stopped tracking")
                return
            }
            scheduler.invalidateFunction(node)
        }
    }

    /// Runs `body`, and schedules the node whenever anything it read changes.
    final func trackDependencies<T>(scheduler: Scheduler, of body: () -> T) -> T {
        isInvalidated = false
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

    final func stopTracking() {
        isInvalidated = false
        listener.take()?.cancel()
        scheduler = nil
    }
}
