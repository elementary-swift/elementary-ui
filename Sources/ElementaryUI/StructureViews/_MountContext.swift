public struct _MountContext: ~Copyable {
    private var layoutNodes: [LayoutNode] = []
    private(set) var isStatic: Bool = true

    let scheduler: Scheduler
    let dom: any DOM.Interactor
    let currentFrameTime: Double  //TODO: remove

    var inheritedTransaction: Transaction = Transaction()
    /// Registration endpoint for transition participants in the currently mounting root.
    var transitionRegistrationSink: MountRootTransitionRegistrationSink? = nil
    /// Transition wrapper depth within the current root. Top-level transitions are depth 0.
    var transitionDepth: Int = 0

    private init(scheduler: Scheduler, dom: any DOM.Interactor) {
        self.scheduler = scheduler
        self.dom = dom
        self.currentFrameTime = 0
    }

    init(ctx: borrowing _CommitContext) {
        self.scheduler = ctx.scheduler
        self.dom = ctx.dom
        self.currentFrameTime = ctx.currentFrameTime
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

    func withChildContext<R>(_ body: (consuming _MountContext) -> R) -> R {
        var child = _MountContext(scheduler: scheduler, dom: dom)
        child.transitionRegistrationSink = transitionRegistrationSink
        child.transitionDepth = transitionDepth
        // inheritedTransaction is intentionally NOT propagated — it is root-scoped only
        return body(child)
    }

    private mutating func appendLayoutNode(_ node: LayoutNode) {
        isStatic = isStatic && node.isStatic
        layoutNodes.append(node)
    }
}

extension _MountContext {
    consuming func takeLayoutNodes() -> [LayoutNode] {
        layoutNodes
    }

    consuming func mountInDOMNode(_ domNode: DOM.Node, observers: [any DOMLayoutObserver]) -> LayoutContainer? {
        if isStatic {
            // TODO: measure if just appending is faster than replacing...
            let refs = layoutNodes.map { $0.staticDOMNode }
            if refs.count == 1 {
                dom.insertChild(refs[0], before: nil, in: domNode)
            } else if refs.count > 1 {
                dom.replaceChildren(refs, in: domNode)
            }
            return nil
        } else {
            let container = LayoutContainer(
                domNode: domNode,
                scheduler: scheduler,
                layoutNodes: layoutNodes,
                layoutObservers: observers
            )
            var commit = _CommitContext(dom: dom, scheduler: scheduler, currentFrameTime: currentFrameTime)
            container.mountInitial(&commit)
            return container
        }
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
