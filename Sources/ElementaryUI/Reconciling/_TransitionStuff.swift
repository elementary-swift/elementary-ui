protocol MountRootTransitionParticipant: AnyObject {
    var mountRootDefaultAnimation: Animation? { get }
    var mountRootIsMounted: Bool { get }
    func mountRootPatchTransitionPhase(_ phase: TransitionPhase, tx: inout _TransactionContext)
}

final class MountRootTransitionCoordinator {
    private var participants: [any MountRootTransitionParticipant] = []
    private var nextRemovalToken: UInt64 = 0
    private var pendingExitCompletions: Int = 0
    private var pendingEnterIdentityPatches: Int = 0
    private var deferredRemovalReady: Bool = false

    private(set) var activeRemovalToken: UInt64?
    private let mountTransaction: Transaction

    init(mountTransaction: Transaction) {
        self.mountTransaction = mountTransaction
    }

    func register(_ participant: any MountRootTransitionParticipant) -> TransitionPhase {
        participants.append(participant)

        guard transitionEffectiveAnimation(for: participant, transaction: mountTransaction) != nil else {
            return .identity
        }

        pendingEnterIdentityPatches += 1
        return .willAppear
    }

    var isRemovalInFlight: Bool {
        activeRemovalToken != nil
    }

    func scheduleEnterIdentityIfNeeded(scheduler: Scheduler) {
        let shouldSchedule = pendingEnterIdentityPatches > 0
        pendingEnterIdentityPatches = 0
        guard shouldSchedule else { return }

        let transaction = mountTransaction
        scheduler.scheduleUpdate { [coordinator = self, transaction] tx in
            coordinator.patchAll(.identity, tx: &tx, transaction: transaction)
        }
    }

    func beginRemoval(tx: inout _TransactionContext, handle: LayoutContainer.Handle?) -> Bool {
        pruneParticipants()

        let live = participants.filter { $0.mountRootIsMounted }
        guard !live.isEmpty else {
            cancelDeferredRemovalState()
            return false
        }

        nextRemovalToken &+= 1
        let token = nextRemovalToken
        activeRemovalToken = token
        pendingExitCompletions = 0
        deferredRemovalReady = false
        let scheduler = tx.scheduler

        for participant in live {
            let animation = transitionEffectiveAnimation(for: participant, transaction: tx.transaction)
            if let animation {
                pendingExitCompletions += 1
                tx.withModifiedTransaction({
                    $0.animation = animation
                    $0.disablesAnimation = false
                    $0.addAnimationCompletion { [coordinator = self, scheduler, handle] in
                        coordinator.notifyExitAnimationCompleted(token: token, scheduler: scheduler, handle: handle)
                    }
                }) { tx in
                    participant.mountRootPatchTransitionPhase(.didDisappear, tx: &tx)
                }
            } else {
                participant.mountRootPatchTransitionPhase(.didDisappear, tx: &tx)
            }
        }

        if pendingExitCompletions == 0 {
            activeRemovalToken = nil
            return false
        }

        return true
    }

    func cancelRemoval(tx: inout _TransactionContext) {
        cancelDeferredRemovalState()
        patchAll(.identity, tx: &tx, transaction: tx.transaction)
    }

    func consumeDeferredRemovalReadySignal() -> Bool {
        let isReady = deferredRemovalReady
        deferredRemovalReady = false
        return isReady
    }

    private func patchAll(_ phase: TransitionPhase, tx: inout _TransactionContext, transaction: Transaction) {
        pruneParticipants()
        for participant in participants where participant.mountRootIsMounted {
            let animation = transitionEffectiveAnimation(for: participant, transaction: transaction)
            if let animation {
                tx.withModifiedTransaction({
                    $0.animation = animation
                    $0.disablesAnimation = false
                }) { tx in
                    participant.mountRootPatchTransitionPhase(phase, tx: &tx)
                }
            } else {
                tx.withModifiedTransaction({
                    $0.animation = nil
                    $0.disablesAnimation = false
                }) { tx in
                    participant.mountRootPatchTransitionPhase(phase, tx: &tx)
                }
            }
        }
    }

    private func notifyExitAnimationCompleted(
        token: UInt64,
        scheduler: Scheduler,
        handle: LayoutContainer.Handle?
    ) {
        guard activeRemovalToken == token else { return }
        if pendingExitCompletions > 0 {
            pendingExitCompletions -= 1
        }
        guard pendingExitCompletions == 0 else { return }

        activeRemovalToken = nil
        deferredRemovalReady = true
        scheduler.scheduleUpdate { tx in
            handle?.reportLayoutChange(&tx)
        }
    }

    private func cancelDeferredRemovalState() {
        activeRemovalToken = nil
        pendingExitCompletions = 0
        deferredRemovalReady = false
    }

    private func pruneParticipants() {
        participants.removeAll { !$0.mountRootIsMounted }
    }
}

private func transitionEffectiveAnimation(
    for participant: any MountRootTransitionParticipant,
    transaction: Transaction
) -> Animation? {
    if transaction.disablesAnimation {
        return nil
    }
    return transaction.animation ?? participant.mountRootDefaultAnimation
}
