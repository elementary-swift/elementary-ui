public struct _MountContext: ~Copyable {
    private var layoutNodes: [LayoutNode] = []
    private(set) var isStatic: Bool = true

    let scheduler: Scheduler
    let dom: any DOM.Interactor
    let currentFrameTime: Double  //TODO: remove

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

    mutating func appendDynamicNode(_ node: any DynamicNode) {
        appendLayoutNode(.dynamicNode(node))
    }

    func withChildContext<R>(_ body: (consuming _MountContext) -> R) -> R {
        body(_MountContext(scheduler: scheduler, dom: dom))
    }

    // TODO: get rid of this...
    mutating func withCommitContext<R>(_ body: (inout _CommitContext) -> R) -> R {
        var context = _CommitContext(
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime
        )
        return body(&context)
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
        case .dynamicNode: fatalError("dynamic node in static node list")
        }
    }
}
