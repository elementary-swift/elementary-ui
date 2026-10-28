import Reactivity

public class _SchedulableNode {
    let depthInTree: Int
    /// Observes what the node's last run read; a change schedules the node to run again.
    private var listener: ReactiveTracking.Listener?

    init(depthInTree: Int) {
        self.depthInTree = depthInTree
    }

    var identifier: ObjectIdentifier { ObjectIdentifier(self) }

    func runUpdate(tx: inout _TransactionContext) {}

    func progressAnimation(tx: inout _TransactionContext) -> AnimationProgressResult {
        .completed
    }

    /// Schedules the node whenever anything it read changes, starting with `dependencies`
    /// collected before the node existed.
    final func startTracking(_ dependencies: consuming ReactiveTracking.AccessedDependencies? = nil, scheduler: Scheduler) {
        listener = ReactiveTracking.Listener(tracking: dependencies) { [self, scheduler] in
            scheduler.invalidateFunction(self)
        }
    }

    /// Whether the node still tracks, that is, it was not unmounted.
    final var isTracking: Bool { listener != nil }

    /// Runs `body` and observes exactly what it reads. Requires ``isTracking``.
    final func trackDependencies<T>(of body: () -> T) -> T {
        listener!.track(body)
    }

    final func stopTracking() {
        listener = nil
    }
}
