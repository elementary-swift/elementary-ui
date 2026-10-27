import Reactivity

public class _SchedulableNode {
    let depthInTree: Int
    var listener: ReactiveTracking.Listener?

    init(depthInTree: Int, scheduler: Scheduler, tracking dependencies: consuming ReactiveTracking.AccessedDependencies? = nil) {
        self.depthInTree = depthInTree
        listener = ReactiveTracking.Listener(tracking: dependencies) { [self] in
            scheduler.invalidateFunction(self)
        }
    }

    var identifier: ObjectIdentifier { ObjectIdentifier(self) }

    func runUpdate(tx: inout _TransactionContext) {}

    func progressAnimation(tx: inout _TransactionContext) -> AnimationProgressResult {
        .completed
    }
}
