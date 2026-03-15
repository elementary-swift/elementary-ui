public struct _MountContext: ~Copyable {
    enum TransitionScope {
        case root(transaction: Transaction, coordinator: MountRootTransitionCoordinator?)
        case nonRoot
    }

    struct MountedOutput {
        let layoutNodes: [LayoutNode]
        let transitionCoordinator: MountRootTransitionCoordinator?
    }

    private var layoutNodes: [LayoutNode] = []
    private(set) var isStatic: Bool = true

    let scheduler: Scheduler
    let dom: any DOM.Interactor
    let currentFrameTime: Double
    let transaction: Transaction

    private var transitionScope: TransitionScope

    fileprivate init(
        dom: any DOM.Interactor,
        scheduler: Scheduler,
        currentFrameTime: Double,
        transaction: Transaction,
        transitionScope: TransitionScope
    ) {
        self.dom = dom
        self.scheduler = scheduler
        self.currentFrameTime = currentFrameTime
        self.transaction = transaction
        self.transitionScope = transitionScope
    }

    mutating func appendStaticElement(_ node: DOM.Node) {
        appendLayoutNode(.elementNode(node))
    }

    mutating func appendStaticText(_ node: DOM.Node) {
        appendLayoutNode(.textNode(node))
    }

    mutating func appendContainer(_ container: MountRootContainer) {
        appendLayoutNode(.container(container))
    }

    mutating func appendTransitionParticipant(_ participant: any MountRootTransitionParticipant) -> TransitionPhase {
        switch transitionScope {
        case .root(let transaction, let coordinator):
            let coordinator = coordinator ?? MountRootTransitionCoordinator(mountTransaction: transaction)
            let phase = coordinator.register(participant)
            transitionScope = .root(transaction: transaction, coordinator: coordinator)
            return phase
        case .nonRoot:
            return .identity
        }
    }

    func withMountRootContext<R>(_ body: (consuming _MountContext) -> R) -> R {
        body(
            _MountContext(
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                transitionScope: .root(transaction: transaction, coordinator: nil)
            )
        )
    }

    mutating func withTransitionBoundary<R>(_ body: (inout _MountContext) -> R) -> R {
        let previousScope = transitionScope
        transitionScope = .nonRoot
        let result = body(&self)
        transitionScope = previousScope
        return result
    }

    func withChildContext<R>(_ body: (consuming _MountContext) -> R) -> R {
        body(
            _MountContext(
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                transitionScope: .nonRoot
            )
        )
    }

    func withCommitContext<R>(_ body: (inout _CommitContext) -> R) -> R {
        var commitContext = _CommitContext(
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime
        )
        return body(&commitContext)
    }

    consuming func takeLayoutNodes() -> [LayoutNode] {
        layoutNodes
    }

    consuming func takeTransitionCoordinatorIfNeeded() -> MountRootTransitionCoordinator? {
        switch transitionScope {
        case .root(_, let coordinator):
            coordinator
        case .nonRoot:
            nil
        }
    }

    consuming func takeMountedOutput() -> MountedOutput {
        let transitionCoordinator: MountRootTransitionCoordinator?
        switch transitionScope {
        case .root(_, let coordinator):
            transitionCoordinator = coordinator
        case .nonRoot:
            transitionCoordinator = nil
        }

        return .init(layoutNodes: layoutNodes, transitionCoordinator: transitionCoordinator)
    }

    consuming func mountInDOMNode(_ domNode: DOM.Node, observers: [any DOMLayoutObserver]) -> LayoutContainer? {
        if isStatic {
            let refs = layoutNodes.map { $0.staticDOMNode }
            if refs.count == 1 {
                dom.insertChild(refs[0], before: nil, in: domNode)
            } else if refs.count > 1 {
                dom.replaceChildren(refs, in: domNode)
            }
            return nil
        }

        let container = LayoutContainer(
            domNode: domNode,
            scheduler: scheduler,
            layoutNodes: layoutNodes,
            layoutObservers: observers
        )
        withCommitContext { commit in
            container.mountInitial(&commit)
        }
        return container
    }

    private mutating func appendLayoutNode(_ node: LayoutNode) {
        isStatic = isStatic && node.isStatic
        layoutNodes.append(node)
    }
}

private extension LayoutNode {
    var staticDOMNode: DOM.Node {
        switch self {
        case .elementNode(let node), .textNode(let node): node
        case .container: fatalError("dynamic container in static node list")
        }
    }
}

extension _CommitContext {
    func withMountContext<R>(
        transaction: Transaction,
        _ body: (consuming _MountContext) -> R
    ) -> R {
        body(
            _MountContext(
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                transitionScope: .root(transaction: transaction, coordinator: nil)
            )
        )
    }
}
