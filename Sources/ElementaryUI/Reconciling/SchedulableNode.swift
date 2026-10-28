import Reactivity

public class _SchedulableNode {
    let depthInTree: Int
    /// Observes what the node's last run read; a change schedules the node to run again.
    /// Created once the node has read anything reactive.
    private var listener: ReactiveTracking.Listener?

    init(depthInTree: Int) {
        self.depthInTree = depthInTree
    }

    var identifier: ObjectIdentifier { ObjectIdentifier(self) }

    func runUpdate(tx: inout _TransactionContext) {}

    func progressAnimation(tx: inout _TransactionContext) -> AnimationProgressResult {
        .completed
    }

    /// Schedules the node whenever anything in `dependencies`, collected before the node
    /// existed, changes.
    final func startTracking(_ dependencies: consuming ReactiveTracking.AccessedDependencies, scheduler: Scheduler) {
        listener = ReactiveTracking.Listener(tracking: dependencies) { [self, scheduler] in
            scheduler.invalidateFunction(self)
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
        listener = nil
    }
}
