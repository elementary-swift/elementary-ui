import Reactivity

public class _SchedulableNode {
    let depthInTree: Int
    /// Created once the node has read anything reactive.
    private var listener: ReactiveTracking.Listener?
    private var scheduler: Scheduler?

    init(depthInTree: Int) {
        self.depthInTree = depthInTree
    }

    var identifier: ObjectIdentifier { ObjectIdentifier(self) }

    func runUpdate(tx: inout _TransactionContext) {}

    func progressAnimation(tx: inout _TransactionContext) -> AnimationProgressResult {
        .completed
    }

    /// Schedules the node whenever `dependencies` change.
    final func startTracking(_ dependencies: consuming ReactiveTracking.AccessedDependencies, scheduler: Scheduler) {
        self.scheduler = scheduler
        // Unretained: the node owns the listener and cancels it when it stops tracking.
        listener = ReactiveTracking.Listener(
            tracking: dependencies,
            context: Unmanaged.passUnretained(self).toOpaque()
        ) { context in
            let node = Unmanaged<_SchedulableNode>.fromOpaque(context).takeUnretainedValue()
            guard let scheduler = node.scheduler else {
                assertionFailure("listener notified after the node stopped tracking")
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
        var result = ReactiveTracking.track(body)
        if let dependencies = result.dependencies.take() {
            startTracking(dependencies, scheduler: scheduler)
        }
        return result.takeValue()
    }

    final func stopTracking() {
        listener.take()?.cancel()
        scheduler = nil
    }
}
