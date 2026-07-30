/// The transition elements owned by one structural mount slot.
///
/// Transition-free slots store only a nil reference. Storage is allocated
/// lazily when a transition reaches an element in the slot.
struct _SlotTransitions: ~Copyable {
    private final class Storage {
        var elements: [_TransitionElement] = []
        var pendingEnterIdentityPatches = 0
    }

    private var storage: Storage?

    mutating func register(
        _ element: _TransitionElement,
        initialPhase: TransitionPhase
    ) {
        let storage: Storage
        if let existing = self.storage {
            storage = existing
        } else {
            storage = Storage()
            self.storage = storage
        }

        storage.elements.append(element)
        if initialPhase == .willAppear {
            storage.pendingEnterIdentityPatches += 1
        }
    }

    func scheduleEnterIdentityIfNeeded(
        scheduler: Scheduler,
        transaction: Transaction
    ) {
        guard
            let storage,
            storage.pendingEnterIdentityPatches > 0
        else {
            return
        }
        storage.pendingEnterIdentityPatches = 0

        let elements = storage.elements
        scheduler.scheduleUpdate { tx in
            patchTransitionElements(
                elements,
                to: .identity,
                tx: &tx,
                transaction: transaction
            )
        }
    }

    borrowing func collectLiveElements(
        into result: inout [_TransitionElement]
    ) {
        guard let storage else { return }
        for element in storage.elements where element.isMounted {
            result.append(element)
        }
    }
}

func transitionInitialPhase(
    defaultAnimation: Animation?,
    transaction: Transaction
) -> TransitionPhase {
    guard
        transitionEffectiveAnimation(
            defaultAnimation: defaultAnimation,
            transaction: transaction
        ) != nil
    else {
        return .identity
    }

    return .willAppear
}

func transitionEffectiveAnimation(
    defaultAnimation: Animation?,
    transaction: Transaction
) -> Animation? {
    if transaction.disablesAnimation {
        return nil
    }
    return transaction.animation ?? defaultAnimation
}

func patchTransitionElements(
    _ elements: [_TransitionElement],
    to phase: TransitionPhase,
    tx: inout _TransactionContext,
    transaction: Transaction
) {
    for element in elements where element.isMounted {
        let animation = transitionEffectiveAnimation(
            defaultAnimation: element.defaultAnimation,
            transaction: transaction
        )
        tx.withModifiedTransaction {
            $0.animation = animation
            $0.disablesAnimation = false
        } run: { tx in
            element.patchPhase(phase, tx: &tx)
        }
    }
}
