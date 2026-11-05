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
    let elements = elements.span
    for index in elements.indices {
        elements[index].patchPhase(phase, tx: &tx, transaction: transaction)
    }
}

extension _TransitionElement {
    /// Patches to `phase`, animated as `transaction` (or the element's default).
    func patchPhase(
        _ phase: TransitionPhase,
        tx: inout _TransactionContext,
        transaction: Transaction
    ) {
        let animation = transitionEffectiveAnimation(
            defaultAnimation: defaultAnimation,
            transaction: transaction
        )
        tx.withModifiedTransaction {
            $0.animation = animation
            $0.disablesAnimation = false
        } run: { tx in
            patchPhase(phase, tx: &tx)
        }
    }
}
