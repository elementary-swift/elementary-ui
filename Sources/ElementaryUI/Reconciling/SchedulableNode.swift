import Reactivity

public class _SchedulableNode {
    let depthInTree: Int
    var trackingSession: TrackingSession?

    init(depthInTree: Int) {
        self.depthInTree = depthInTree
    }

    var identifier: ObjectIdentifier { ObjectIdentifier(self) }

    func runUpdate(tx: inout _TransactionContext) {}

    func progressAnimation(tx: inout _TransactionContext) -> AnimationProgressResult {
        .completed
    }

    func startTracking(for accessList: ReactivePropertyAccessList, scheduler: Scheduler) {
        let session = ReactiveTrackingSession()
        session.trackWillSet(for: accessList) {
            [self, scheduler] _ in
            scheduler.invalidateFunction(self)
        }
        self.trackingSession = TrackingSession(session.cancel)
    }
}
