import BasicContainers

/// Keeps a removed structural slot alive until its transitions have finished.
final class _TransitionRemoval: _DeferredRemoval {
    private let transitionElements: [_TransitionElement]
    private let nestedRemovals: [_DeferredRemoval]
    private let leavingDOMNodes: [DOM.Node]
    private let handle: LayoutContainer.Handle?

    private var pendingAnimationCompletions = 0
    private var isCancelled = false

    private init(
        transitionElements: [_TransitionElement],
        nestedRemovals: [_DeferredRemoval],
        leavingDOMNodes: [DOM.Node],
        handle: LayoutContainer.Handle?
    ) {
        self.transitionElements = transitionElements
        self.nestedRemovals = nestedRemovals
        self.leavingDOMNodes = leavingDOMNodes
        self.handle = handle
    }

    override class func startIfNeeded(
        for mounted: borrowing MountContainer.Slot.Mounted,
        handle: LayoutContainer.Handle?,
        tx: inout _TransactionContext
    ) -> _DeferredRemoval? {
        var targets = _TransitionRemovalTargets()
        targets.collect(mounted: mounted)
        return startIfNeeded(
            for: targets,
            handle: handle,
            tx: &tx
        )
    }

    private static func startIfNeeded(
        for targets: _TransitionRemovalTargets,
        handle: LayoutContainer.Handle?,
        tx: inout _TransactionContext
    ) -> _TransitionRemoval? {
        let nestedRemovals = targets.nestedRemovals.filter {
            !$0.isReadyForRemoval
        }
        let hasAnimatedElement = targets.transitionElements.contains { element in
            transitionEffectiveAnimation(
                defaultAnimation: element.defaultAnimation,
                transaction: tx.transaction
            ) != nil
        }

        guard hasAnimatedElement || !nestedRemovals.isEmpty else {
            for element in targets.transitionElements {
                element.patchPhase(.didDisappear, tx: &tx)
            }
            return nil
        }

        let removal = _TransitionRemoval(
            transitionElements: targets.transitionElements,
            nestedRemovals: nestedRemovals,
            leavingDOMNodes: targets.leavingDOMNodes,
            handle: handle
        )
        removal.startExitTransitions(tx: &tx)
        guard !removal.isReadyForRemoval else { return nil }
        removal.reportLeavingDOMNodes(tx: &tx)
        return removal
    }

    override var isReadyForRemoval: Bool {
        isCancelled
            || (pendingAnimationCompletions == 0
                && nestedRemovals.allSatisfy(\.isReadyForRemoval))
    }

    override func cancel(tx: inout _TransactionContext) {
        guard !isCancelled else { return }
        isCancelled = true
        pendingAnimationCompletions = 0

        for removal in nestedRemovals {
            removal.cancel(tx: &tx)
        }
        patchTransitionElements(
            transitionElements,
            to: .identity,
            tx: &tx,
            transaction: tx.transaction
        )
        for node in leavingDOMNodes {
            handle?.reportReenteringElement(node, &tx)
        }
    }

    private func startExitTransitions(tx: inout _TransactionContext) {
        let transaction = tx.transaction
        let scheduler = tx.scheduler

        for element in transitionElements {
            guard
                let animation = transitionEffectiveAnimation(
                    defaultAnimation: element.defaultAnimation,
                    transaction: transaction
                )
            else {
                element.patchPhase(.didDisappear, tx: &tx)
                continue
            }

            pendingAnimationCompletions += 1
            tx.withModifiedTransaction {
                $0.animation = animation
                $0.disablesAnimation = false
                $0.addAnimationCompletion(criteria: .removed) {
                    [self, scheduler] in
                    exitAnimationCompleted(scheduler: scheduler)
                }
            } run: { tx in
                element.patchPhase(.didDisappear, tx: &tx)
            }
            transaction._animationTracker.checkCallbacks()
        }
    }

    private func reportLeavingDOMNodes(tx: inout _TransactionContext) {
        for node in leavingDOMNodes {
            handle?.reportLeavingElement(node, &tx)
        }
    }

    private func exitAnimationCompleted(scheduler: Scheduler) {
        guard !isCancelled, pendingAnimationCompletions > 0 else {
            return
        }
        pendingAnimationCompletions -= 1
        guard pendingAnimationCompletions == 0 else { return }

        // Completion callbacks run outside reconciliation. Re-enter through the
        // scheduler so the owning container can promote this leaving slot.
        scheduler.scheduleUpdate { [handle] tx in
            handle?.reportLayoutChange(&tx)
        }
    }
}

private struct _TransitionRemovalTargets {
    var transitionElements: [_TransitionElement] = []
    var nestedRemovals: [_DeferredRemoval] = []
    var leavingDOMNodes: [DOM.Node] = []

    mutating func collect(
        mounted: borrowing MountContainer.Slot.Mounted
    ) {
        mounted.transitionRoot.collectLiveElements(
            into: &transitionElements
        )
        mounted.layoutNodes.collectTransitionRemovalTargets(into: &self)
    }
}

private extension MountContainer {
    func collectTransitionRemovalTargets(
        into targets: inout _TransitionRemovalTargets
    ) {
        forEachMountedSlot { mounted in
            if let removal = mounted.deferredRemoval {
                // A nested removal already owns its transition elements. The
                // parent waits for it instead of starting them a second time.
                targets.nestedRemovals.append(removal)
            } else {
                targets.collect(mounted: mounted)
            }
        }
    }
}

private extension LayoutNode {
    func collectTransitionRemovalTargets(
        into targets: inout _TransitionRemovalTargets
    ) {
        switch self {
        case .elementNode(let node):
            targets.leavingDOMNodes.append(node)
        case .textNode:
            break
        case .container(let container):
            container.collectTransitionRemovalTargets(into: &targets)
        }
    }
}

private extension RigidArray where Element == LayoutNode {
    borrowing func collectTransitionRemovalTargets(
        into targets: inout _TransitionRemovalTargets
    ) {
        let nodes = span
        for index in nodes.indices {
            nodes[unchecked: index]
                .collectTransitionRemovalTargets(into: &targets)
        }
    }
}
