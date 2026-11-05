import BasicContainers
import ContainersPreview

public struct _MountContext: ~Copyable, ~Escapable {
    private var nodeStack: ScratchStack<LayoutNode>
    private(set) var isStatic: Bool = true

    private(set) var slotTransitions: _SlotTransitions?

    /// The unmount work of the enclosing slot (or root).
    private var unmounts: _MutableRef<UnmountRegistry>

    // NOTE: we could use a fancy Inout<_CommitContext> here.. but maybe not worth it
    let scheduler: Scheduler
    let dom: DOMInteractor
    let currentFrameTime: Double
    let transaction: Transaction

    @_lifetime(copy nodeStack, copy unmounts)
    init(
        nodeStack: consuming ScratchStack<LayoutNode>,
        unmounts: consuming _MutableRef<UnmountRegistry>,
        dom: DOMInteractor,
        scheduler: Scheduler,
        currentFrameTime: Double,
        transaction: Transaction,
        slotTransitions: consuming _SlotTransitions? = nil
    ) {
        self.unmounts = unmounts
        self.nodeStack = consume nodeStack
        self.dom = dom
        self.scheduler = scheduler
        self.currentFrameTime = currentFrameTime
        self.transaction = transaction
        self.slotTransitions = consume slotTransitions
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

    /// Registers unmount work for the enclosing slot. Register after mounting
    /// children so the registry unmounts children first.
    mutating func registerUnmount(_ entry: any Unmountable) {
        unmounts.value.register(entry)
    }

    mutating func registerTransition(
        _ transitionedElement: _TransitionElement,
        initialPhase: TransitionPhase
    ) {
        precondition(slotTransitions != nil)
        slotTransitions!.register(
            transitionedElement,
            initialPhase: initialPhase
        )
    }

    /// Mounts one structural slot: runs `makeNode` in a nested layout-node
    /// frame with a fresh transition registry, then packages the node, its
    /// unmount work, its layout nodes, and its transitions into a slot.
    // inline(never): keeps slot mounting out of every mount site (code size)
    @inline(never)
    mutating func mountSlot(
        key: _ViewKey,
        newKeyIndex: Int,
        env: borrowing _ViewContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) -> MountContainer.Slot {
        var unmounts = UnmountRegistry()
        return nodeStack.withNestedStack { slotStack in
            var slotCtx = _MountContext(
                nodeStack: slotStack,
                unmounts: _MutableRef(&unmounts),
                dom: dom,
                scheduler: scheduler,
                currentFrameTime: currentFrameTime,
                transaction: transaction,
                slotTransitions: _SlotTransitions()
            )
            let node = makeNode(newKeyIndex, env, &slotCtx)

            let transitions = slotCtx.slotTransitions.take()!
            transitions.scheduleEnterIdentityIfNeeded(
                scheduler: scheduler,
                transaction: transaction
            )
            // consumes the context, ending its borrow of `unmounts`
            let layoutNodes = slotCtx.takeSlotLayoutNodes()

            return MountContainer.Slot(
                key: key,
                node: node,
                unmounts: unmounts.take(),
                layoutNodes: layoutNodes,
                transitions: transitions
            )
        }
    }

    /// A context for an element's children: a nested layout-node frame that
    /// registers unmount work with the same slot.
    mutating func withChildContext<R: ~Copyable>(_ body: (consuming _MountContext) -> R) -> R {
        let dom = dom
        let scheduler = scheduler
        let currentFrameTime = currentFrameTime
        let transaction = transaction
        return Self.withNestedFrame(&nodeStack, &unmounts) { childStack, childUnmounts in
            body(
                _MountContext(
                    nodeStack: childStack,
                    unmounts: childUnmounts,
                    dom: dom,
                    scheduler: scheduler,
                    currentFrameTime: currentFrameTime,
                    transaction: transaction
                )
            )
        }
    }

    // Static, so the two exclusive borrows do not overlap an access to self.
    private static func withNestedFrame<R: ~Copyable>(
        _ nodeStack: inout ScratchStack<LayoutNode>,
        _ unmounts: inout _MutableRef<UnmountRegistry>,
        _ body: (consuming ScratchStack<LayoutNode>, consuming _MutableRef<UnmountRegistry>) -> R
    ) -> R {
        nodeStack.withNestedStack { childStack in
            body(childStack, _MutableRef(&unmounts.value))
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

    consuming func mountInDOMNode(
        _ domNode: DOM.Node,
        observers: [DOMLayoutObserver] = [],
        ownsAllChildren: Bool = true
    ) -> LayoutContainer? {
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
            layoutObservers: observers,
            ownsAllChildren: ownsAllChildren
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

    private consuming func takeSlotLayoutNodes() -> SlotLayoutNodes {
        guard nodeStack.count == 1 else { return .many(takeMaterializedLayoutNodes()) }
        var node: LayoutNode?
        nodeStack.consume { span in node = span.removeFirst() }
        return .one(node!)
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
