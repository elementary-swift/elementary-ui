import BasicContainers
import ContainersPreview

public struct _MountContext: ~Copyable, ~Escapable {
    private var nodeStack: ScratchStack<LayoutNode>
    private(set) var isStatic: Bool = true

    private(set) var transitionRoot: _TransitionRoot?

    // NOTE: we could use a fancy Inout<_CommitContext> here.. but maybe not worth it
    let scheduler: Scheduler
    let dom: DOMInteractor
    let currentFrameTime: Double
    let transaction: Transaction

    @_lifetime(copy nodeStack)
    init(
        nodeStack: consuming ScratchStack<LayoutNode>,
        dom: DOMInteractor,
        scheduler: Scheduler,
        currentFrameTime: Double,
        transaction: Transaction,
        transitionRoot: consuming _TransitionRoot? = nil
    ) {
        self.nodeStack = consume nodeStack
        self.dom = dom
        self.scheduler = scheduler
        self.currentFrameTime = currentFrameTime
        self.transaction = transaction
        self.transitionRoot = consume transitionRoot
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

    mutating func registerTransition(
        _ transitionedElement: _TransitionElement,
        initialPhase: TransitionPhase
    ) {
        precondition(transitionRoot != nil)
        transitionRoot!.register(
            transitionedElement,
            initialPhase: initialPhase
        )
    }

    mutating func withMountedSlotContext<R: ~Copyable>(
        _ body: (consuming _MountContext) -> R
    ) -> R {
        nodeStack.withNestedStack { childScratch in
            let childContext = _MountContext(
                nodeStack: consume childScratch,
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                transitionRoot: _TransitionRoot()
            )
            return body(childContext)
        }
    }

    mutating func withChildContext<R: ~Copyable>(_ body: (consuming _MountContext) -> R) -> R {
        nodeStack.withNestedStack { childStack in
            body(
                _MountContext(
                    nodeStack: childStack,
                    dom: dom,
                    scheduler: scheduler,
                    currentFrameTime: currentFrameTime,
                    transaction: transaction,
                    transitionRoot: nil
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

    consuming func makeMountedSlot(
        newKeyIndex: Int,
        viewContext: borrowing _ViewContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) -> MountContainer.Slot.Mounted {
        let node = makeNode(newKeyIndex, viewContext, &self)
        let transitionRoot = self.transitionRoot.take()!
        transitionRoot.scheduleEnterIdentityIfNeeded(
            scheduler: scheduler,
            transaction: transaction
        )

        return MountContainer.Slot.Mounted(
            node: node,
            layoutNodes: takeMaterializedLayoutNodes(),
            placement: .unchanged,
            transitionRoot: consume transitionRoot,
            deferredRemoval: nil
        )
    }

    consuming func mountInDOMNode(_ domNode: DOM.Node, observers: [DOMLayoutObserver] = []) -> LayoutContainer? {
        if isStatic {
            let dom = dom
            nodeStack.consume { span in
                for index in span.indices {
                    dom.appendChild(span[unchecked: index].staticDOMNode, to: domNode)
                }
            }
            return nil
        }

        let dom = dom
        let scheduler = scheduler
        let currentFrameTime = currentFrameTime
        let container = LayoutContainer(
            domNode: domNode,
            scheduler: scheduler,
            layoutNodes: takeMaterializedLayoutNodes(),
            layoutObservers: observers
        )

        var commit = _CommitContext(
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime
        )

        container.commitInitialLayout(&commit)
        return container
    }

    private consuming func takeMaterializedLayoutNodes() -> RigidArray<LayoutNode> {
        var result = RigidArray<LayoutNode>(capacity: nodeStack.count)
        self.nodeStack.consume { span in
            result.append(moving: &span)
        }
        return result
    }

    private mutating func appendLayoutNode(_ node: LayoutNode) {
        isStatic = isStatic && node.isStatic
        nodeStack.append(node)
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
