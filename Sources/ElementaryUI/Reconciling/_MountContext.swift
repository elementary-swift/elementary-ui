import BasicContainers

public struct _MountContext: ~Copyable {
    private var layoutNodes: UniqueArray<LayoutNode> = .init(capacity: 4)
    private(set) var isStatic: Bool = true

    private var transitionCoordinator: MountRootTransitionCoordinator?
    private var isRoot: Bool

    // NOTE: we could use a fancy Inout<_CommitContext> here.. but maybe not worth it
    let scheduler: Scheduler
    let dom: any DOM.Interactor
    let currentFrameTime: Double
    let transaction: Transaction

    fileprivate init(
        dom: any DOM.Interactor,
        scheduler: Scheduler,
        currentFrameTime: Double,
        transaction: Transaction,
        isRoot: Bool
    ) {
        self.dom = dom
        self.scheduler = scheduler
        self.currentFrameTime = currentFrameTime
        self.transaction = transaction
        self.isRoot = isRoot
    }

    mutating func appendStaticElement(_ node: DOM.Node) {
        appendLayoutNode(.elementNode(node))
    }

    mutating func appendStaticText(_ node: DOM.Node) {
        appendLayoutNode(.textNode(node))
    }

    mutating func appendContainer(_ container: MountContainer) {
        appendLayoutNode(.container(container))
    }

    mutating func appendTransitionParticipant(_ participant: any MountRootTransitionParticipant) -> TransitionPhase {
        guard isRoot else { return .identity }

        let coordinator = transitionCoordinator ?? MountRootTransitionCoordinator(mountTransaction: transaction)
        let phase = coordinator.register(participant)
        self.transitionCoordinator = coordinator
        return phase
    }

    func withMountRootContext<R: ~Copyable>(_ body: (consuming _MountContext) -> R) -> R {
        body(
            _MountContext(
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                isRoot: true
            )
        )
    }

    mutating func withTransitionBoundary<R>(_ body: (inout _MountContext) -> R) -> R {
        let previousIsRoot = isRoot
        isRoot = false
        let result = body(&self)
        isRoot = previousIsRoot
        return result
    }

    func withChildContext<R: ~Copyable>(_ body: (consuming _MountContext) -> R) -> R {
        body(
            _MountContext(
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                isRoot: false
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

    consuming func makeLayoutContainer(
        domNode: DOM.Node,
        observers: [any DOMLayoutObserver]
    ) -> LayoutContainer {
        let layoutNodes = RigidArray(consuming: consume layoutNodes)
        return LayoutContainer(
            domNode: domNode,
            scheduler: scheduler,
            layoutNodes: consume layoutNodes,
            layoutObservers: observers
        )
    }

    consuming func makeMountedState(
        newKeyIndex: Int,
        viewContext: borrowing _ViewContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) -> MountContainer.Slot.Mounted {
        var mountContext = consume self
        let node = makeNode(newKeyIndex, viewContext, &mountContext)
        return MountContainer.Slot.Mounted(
            node: node,
            layoutNodes: RigidArray(consuming: consume mountContext.layoutNodes),
            didMove: false,
            transitionCoordinator: mountContext.transitionCoordinator
        )
    }

    consuming func mountInDOMNode(_ domNode: DOM.Node, observers: [any DOMLayoutObserver]) -> LayoutContainer? {
        if isStatic {
            if layoutNodes.count == 1 {
                dom.appendChild(layoutNodes[0].staticDOMNode, to: domNode)
            } else if layoutNodes.count > 1 {
                let nodes = layoutNodes.span
                for index in nodes.indices {
                    dom.appendChild(nodes[unchecked: index].staticDOMNode, to: domNode)
                }
            }
            return nil
        }

        let dom = self.dom
        let scheduler = self.scheduler
        let currentFrameTime = self.currentFrameTime
        let container = makeLayoutContainer(domNode: domNode, observers: observers)
        var commit = _CommitContext(
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime
        )
        container.mountInitial(&commit)
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
    func withMountContext<R: ~Copyable>(
        transaction: Transaction,
        _ body: (consuming _MountContext) -> R
    ) -> R {
        body(
            _MountContext(
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                isRoot: true
            )
        )
    }
}
