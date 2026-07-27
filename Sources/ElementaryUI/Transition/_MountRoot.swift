// TODO-TRANSITION: simplify this, AI is too stupid

import BasicContainers

/// Transition participants owned by one structural mount slot.
///
/// This is inline slot state. The array allocates only after a transition
/// reaches an element in this mount root.
struct _MountRoot: ~Copyable {
    private var elements: [_TransitionedElement] = []
    private var pendingEnterIdentityPatches = 0

    mutating func register(
        _ element: _TransitionedElement,
        initialPhase: TransitionPhase
    ) {
        elements.append(element)
        if initialPhase == .willAppear {
            pendingEnterIdentityPatches += 1
        }
    }

    mutating func scheduleEnterIdentityIfNeeded(
        scheduler: Scheduler,
        transaction: Transaction
    ) {
        guard pendingEnterIdentityPatches > 0 else { return }
        pendingEnterIdentityPatches = 0

        let elements = self.elements
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
        into result: inout [_TransitionedElement]
    ) {
        for element in elements where element.isMounted {
            result.append(element)
        }
    }
}

final class _TransitionRemoval: Scheduler.TransitionRemoval {
    private let elements: [_TransitionedElement]
    private let dependencies: [_TransitionRemoval]
    private let leavingElements: [DOM.Node]
    private let handle: LayoutContainer.Handle?

    private var pendingCompletions = 0
    private var isCancelled = false

    private init(
        elements: [_TransitionedElement],
        dependencies: [_TransitionRemoval],
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
    ) -> _TransitionRemoval? {
        var targets = _TransitionRemovalTargets()
        targets.collect(mounted: mounted)
        return begin(
            targets: targets,
            handle: handle,
            tx: &tx
        )
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

    var isReady: Bool {
        guard !isCancelled, pendingCompletions == 0 else {
            return isCancelled
        }
        for dependency in dependencies where !dependency.isReady {
            return false
        }
        return true
    }

    func cancel(tx: inout _TransactionContext) {
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
            let animation = transitionEffectiveAnimation(
                defaultAnimation: element.defaultAnimation,
                transaction: transaction
            )
            if let animation {
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
            } else {
                element.patchPhase(.didDisappear, tx: &tx)
            }
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

extension Scheduler {
    func installTransitionRemoval() {
        transitionRemoval = _TransitionRemoval.self
    }
}

struct _TransitionRemovalTargets {
    var elements: [_TransitionedElement] = []
    var dependencies: [_TransitionRemoval] = []
    var leavingElements: [DOM.Node] = []

    mutating func collect(
        mounted: borrowing MountContainer.Slot.Mounted
    ) {
        mounted.mountRoot.collectLiveElements(into: &elements)
        mounted.layoutNodes.collectTransitionRemovalTargets(into: &self)
    }
}

private extension MountContainer {
    func collectTransitionRemovalTargets(
        into targets: inout _TransitionRemovalTargets
    ) {
        for index in activeSlots.indices {
            activeSlots[index].collectTransitionRemovalTargets(into: &targets)
        }
        for index in leavingSlots.indices {
            leavingSlots[index].collectTransitionRemovalTargets(into: &targets)
        }
    }
}

private extension MountContainer.Slot {
    mutating func collectTransitionRemovalTargets(
        into targets: inout _TransitionRemovalTargets
    ) {
        withMounted { mounted in
            if let removal = mounted.transitionRemoval {
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

private func patchTransitionElements(
    _ elements: [_TransitionedElement],
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
