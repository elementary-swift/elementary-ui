import BasicContainers

/// Keeps a removed structural slot alive until its transitions have finished.
final class _TransitionRemoval: _DeferredRemoval {
    private let elements: [_TransitionElement]
    private let dependencies: [_DeferredRemoval]
    private let leavingElements: [DOM.Node]
    private let handle: LayoutContainer.Handle?

    private var pendingCompletions = 0
    private var isCancelled = false

    private init(
        elements: [_TransitionElement],
        dependencies: [_DeferredRemoval],
        leavingElements: [DOM.Node],
        handle: LayoutContainer.Handle?
    ) {
        self.elements = elements
        self.dependencies = dependencies
        self.leavingElements = leavingElements
        self.handle = handle
    }

    override class func begin(
        mounted: borrowing MountContainer.Slot.Mounted,
        handle: LayoutContainer.Handle?,
        tx: inout _TransactionContext
    ) -> _DeferredRemoval? {
        var targets = _TransitionRemovalTargets()
        targets.collect(mounted: mounted)
        return begin(targets: targets, handle: handle, tx: &tx)
    }

    private static func begin(
        targets: _TransitionRemovalTargets,
        handle: LayoutContainer.Handle?,
        tx: inout _TransactionContext
    ) -> _TransitionRemoval? {
        let dependencies = targets.dependencies.filter { !$0.isReady }
        let hasAnimatedElement = targets.elements.contains { element in
            transitionEffectiveAnimation(
                defaultAnimation: element.defaultAnimation,
                transaction: tx.transaction
            ) != nil
        }

        guard hasAnimatedElement || !dependencies.isEmpty else {
            for element in targets.elements {
                element.patchPhase(.didDisappear, tx: &tx)
            }
            return nil
        }

        let removal = _TransitionRemoval(
            elements: targets.elements,
            dependencies: dependencies,
            leavingElements: targets.leavingElements,
            handle: handle
        )
        removal.start(tx: &tx)
        guard !removal.isReady else { return nil }
        removal.reportLeavingElements(tx: &tx)
        return removal
    }

    override var isReady: Bool {
        guard !isCancelled, pendingCompletions == 0 else {
            return isCancelled
        }
        return dependencies.allSatisfy { $0.isReady }
    }

    override func cancel(tx: inout _TransactionContext) {
        guard !isCancelled else { return }
        isCancelled = true
        pendingCompletions = 0

        for dependency in dependencies {
            dependency.cancel(tx: &tx)
        }
        patchTransitionElements(
            elements,
            to: .identity,
            tx: &tx,
            transaction: tx.transaction
        )
        for node in leavingElements {
            handle?.reportReenteringElement(node, &tx)
        }
    }

    private func start(tx: inout _TransactionContext) {
        let transaction = tx.transaction
        let scheduler = tx.scheduler

        for element in elements {
            guard
                let animation = transitionEffectiveAnimation(
                    defaultAnimation: element.defaultAnimation,
                    transaction: transaction
                )
            else {
                element.patchPhase(.didDisappear, tx: &tx)
                continue
            }

            pendingCompletions += 1
            tx.withModifiedTransaction {
                $0.animation = animation
                $0.disablesAnimation = false
                $0.addAnimationCompletion(criteria: .removed) {
                    [self, scheduler] in
                    animationCompleted(scheduler: scheduler)
                }
            } run: { tx in
                element.patchPhase(.didDisappear, tx: &tx)
            }
            transaction._animationTracker.checkCallbacks()
        }
    }

    private func reportLeavingElements(tx: inout _TransactionContext) {
        for node in leavingElements {
            handle?.reportLeavingElement(node, &tx)
        }
    }

    private func animationCompleted(scheduler: Scheduler) {
        guard !isCancelled, pendingCompletions > 0 else { return }
        pendingCompletions -= 1
        guard pendingCompletions == 0 else { return }

        scheduler.scheduleUpdate { [handle] tx in
            handle?.reportLayoutChange(&tx)
        }
    }
}

private struct _TransitionRemovalTargets {
    var elements: [_TransitionElement] = []
    var dependencies: [_DeferredRemoval] = []
    var leavingElements: [DOM.Node] = []

    mutating func collect(
        mounted: borrowing MountContainer.Slot.Mounted
    ) {
        mounted.transitionRoot.collectLiveElements(into: &elements)
        mounted.layoutNodes.collectTransitionRemovalTargets(into: &self)
    }
}

private extension MountContainer {
    func collectTransitionRemovalTargets(
        into targets: inout _TransitionRemovalTargets
    ) {
        forEachMountedSlot { mounted in
            if let removal = mounted.deferredRemoval {
                targets.dependencies.append(removal)
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
            targets.leavingElements.append(node)
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
