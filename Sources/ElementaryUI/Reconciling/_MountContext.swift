import BasicContainers
import ContainersPreview

public struct _MountContext: ~Copyable, ~Escapable {
    private var layoutNodeScratch: ScratchStack<LayoutNode>
    private(set) var isStatic: Bool = true

    private var transitionCoordinator: MountRootTransitionCoordinator?
    private var isRoot: Bool

    // NOTE: we could use a fancy Inout<_CommitContext> here.. but maybe not worth it
    let scheduler: Scheduler
    let dom: any DOM.Interactor
    let currentFrameTime: Double
    let transaction: Transaction

    @_lifetime(copy layoutNodeScratch)
    fileprivate init(
        layoutNodeScratch: consuming ScratchStack<LayoutNode>,
        dom: any DOM.Interactor,
        scheduler: Scheduler,
        currentFrameTime: Double,
        transaction: Transaction,
        isRoot: Bool
    ) {
        self.layoutNodeScratch = consume layoutNodeScratch
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

    mutating func withMountRootContext<R: ~Copyable>(_ body: (consuming _MountContext) -> R) -> R {
        layoutNodeScratch.withNestedFrame { childScratch in
            let childContext = _MountContext(
                layoutNodeScratch: consume childScratch,
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                isRoot: true
            )
            let result = body(childContext)
            return result
        }
    }

    mutating func withTransitionBoundary<R>(_ body: (inout _MountContext) -> R) -> R {
        let previousIsRoot = isRoot
        isRoot = false
        let result = body(&self)
        isRoot = previousIsRoot
        return result
    }

    mutating func withChildContext<R: ~Copyable>(_ body: (consuming _MountContext) -> R) -> R {
        layoutNodeScratch.withNestedFrame { childScratch in
            body(
                _MountContext(
                    layoutNodeScratch: consume childScratch,
                    dom: dom,
                    scheduler: scheduler,
                    currentFrameTime: currentFrameTime,
                    transaction: transaction,
                    isRoot: false
                )
            )
        }
    }

    func withCommitContext<R>(_ body: (inout _CommitContext) -> R) -> R {
        var commitContext = _CommitContext(
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime
        )
        return body(&commitContext)
    }

    consuming func consumeAsLayoutContainer(
        domNode: DOM.Node,
        observers: [any DOMLayoutObserver]
    ) -> LayoutContainer {
        let scheduler = self.scheduler
        let layoutNodes = takeMaterializedLayoutNodes()
        return LayoutContainer(
            domNode: domNode,
            scheduler: scheduler,
            layoutNodes: consume layoutNodes,
            layoutObservers: observers
        )
    }

    consuming func consumeAsMountedState(
        newKeyIndex: Int,
        viewContext: borrowing _ViewContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) -> MountContainer.Slot.Mounted {
        let node = makeNode(newKeyIndex, viewContext, &self)
        let transitionCoordinator = self.transitionCoordinator

        return MountContainer.Slot.Mounted(
            node: node,
            layoutNodes: takeMaterializedLayoutNodes(),
            didMove: false,
            transitionCoordinator: transitionCoordinator
        )
    }

    consuming func mountInDOMNode(_ domNode: DOM.Node, observers: [any DOMLayoutObserver]) -> LayoutContainer? {
        if isStatic {
            let dom = dom
            layoutNodeScratch.consumeFrame { span in
                for index in span.indices {
                    dom.appendChild(span[unchecked: index].staticDOMNode, to: domNode)
                }
            }
            return nil
        }

        let dom = dom
        let scheduler = scheduler
        let currentFrameTime = currentFrameTime
        let container = consumeAsLayoutContainer(domNode: domNode, observers: observers)
        var commit = _CommitContext(
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime
        )
        container.mountInitial(&commit)
        return container
    }

    private consuming func takeMaterializedLayoutNodes() -> RigidArray<LayoutNode> {
        var result = RigidArray<LayoutNode>(capacity: layoutNodeScratch.count)
        self.layoutNodeScratch.consumeFrame { span in
            result.append(moving: &span)
        }
        return result
    }

    private mutating func appendLayoutNode(_ node: LayoutNode) {
        isStatic = isStatic && node.isStatic
        layoutNodeScratch.append(node)
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
        scheduler.withLayoutNodeScratchFrame { scratch in
            body(
                _MountContext(
                    layoutNodeScratch: consume scratch,
                    dom: dom,
                    scheduler: scheduler,
                    currentFrameTime: currentFrameTime,
                    transaction: transaction,
                    isRoot: true
                )
            )
        }
    }
}
