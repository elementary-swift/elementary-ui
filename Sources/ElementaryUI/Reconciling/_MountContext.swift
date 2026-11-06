import BasicContainers
import SpanPreview

/// Collects what a mount produces into scratch frames, then hands it to its
/// owner: an element takes its children's layout nodes, a slot takes its
/// layout nodes and members, the root takes both.
///
/// An element's children pass their members on to the enclosing slot.
public struct _MountContext: ~Copyable, ~Escapable {
    private var layoutNodes: ScratchFrame<LayoutNode>
    private var members: ScratchFrame<SlotMember>

    /// Only a slot's top level may hold transition elements: a slot is what
    /// defers its removal while they play.
    let acceptsTransitions: Bool
    private(set) var isStatic: Bool = true

    let scheduler: Scheduler
    let dom: DOMInteractor
    let currentFrameTime: Double
    let transaction: Transaction

    @_lifetime(copy layoutNodes, copy members)
    init(
        layoutNodes: consuming ScratchFrame<LayoutNode>,
        members: consuming ScratchFrame<SlotMember>,
        acceptsTransitions: Bool = false,
        dom: DOMInteractor,
        scheduler: Scheduler,
        currentFrameTime: Double,
        transaction: Transaction
    ) {
        self.layoutNodes = layoutNodes
        self.members = members
        self.acceptsTransitions = acceptsTransitions
        self.dom = dom
        self.scheduler = scheduler
        self.currentFrameTime = currentFrameTime
        self.transaction = transaction
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

    /// Registers unmount work with the enclosing slot. Register after mounting
    /// children so the slot unmounts children first.
    mutating func registerUnmount(_ entry: any Unmountable) {
        members.append(.unmountable(entry))
    }

    mutating func registerTransition(_ element: _TransitionElement) {
        precondition(acceptsTransitions)
        members.append(.transition(element))
    }

    // MARK: nested contexts

    /// A context for an element's children. Finish it with `mountInDOMNode`.
    @_lifetime(&self)
    mutating func childContext() -> _MountContext {
        nested(acceptsTransitions: false)
    }

    /// Mounts one structural slot and packages its node, layout nodes, and
    /// members.
    // inline(never): keeps slot mounting out of every mount site (code size)
    @inline(never)
    mutating func mountSlot(
        key: _ViewKey,
        newKeyIndex: Int,
        env: borrowing _ViewContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) -> MountContainer.Slot {
        var slotCtx = nested(acceptsTransitions: true)
        let node = makeNode(newKeyIndex, env, &slotCtx)
        return slotCtx.finishSlot(key: key, node: node)
    }

    @_lifetime(&self)
    private mutating func nested(acceptsTransitions: Bool) -> _MountContext {
        _MountContext(
            layoutNodes: layoutNodes.nested(),
            members: members.nested(),
            acceptsTransitions: acceptsTransitions,
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime,
            transaction: transaction
        )
    }

    // MARK: finishing
    //
    // Finishing a nested context consumes it: a context with a deinit lives
    // until the end of its scope otherwise, past where its parent appends again.

    private consuming func finishSlot(key: _ViewKey, node: consuming AnyReconcilable) -> MountContainer.Slot {
        let layoutNodes = takeSlotLayoutNodes()
        return MountContainer.Slot(
            key: key,
            node: node,
            layoutNodes: layoutNodes,
            members: SlotMembers(members.take())
        )
    }

    /// Mounts the root's layout into `domNode` and hands over its members.
    mutating func mountRoot(in domNode: DOM.Node) -> SlotMembers {
        mountLayout(in: domNode, observers: [], ownsAllChildren: false)
        return SlotMembers(members.take())
    }

    /// Mounts an element's children into `domNode`. Their members stay with
    /// the enclosing slot.
    consuming func mountInDOMNode(
        _ domNode: DOM.Node,
        observers: [DOMLayoutObserver] = []
    ) {
        mountLayout(in: domNode, observers: observers, ownsAllChildren: true)
        members.passToParent()
    }

    func withCommitContext<R>(_ body: (inout _CommitContext) -> R) -> R {
        var commitContext = _CommitContext(
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime
        )
        return body(&commitContext)
    }

    private mutating func mountLayout(
        in domNode: DOM.Node,
        observers: [DOMLayoutObserver],
        ownsAllChildren: Bool
    ) {
        if isStatic {
            let dom = dom
            layoutNodes.drain { nodes in
                for index in nodes.indices {
                    dom.appendChild(nodes[unchecked: index].staticDOMNode, to: domNode)
                }
            }
            return
        }

        let container = LayoutContainer(
            domNode: domNode,
            scheduler: scheduler,
            layoutNodes: layoutNodes.take(),
            layoutObservers: observers,
            ownsAllChildren: ownsAllChildren
        )

        var commit = _CommitContext(
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime
        )

        container.commitInitialLayout(&commit)
    }

    private mutating func takeSlotLayoutNodes() -> SlotLayoutNodes {
        guard layoutNodes.count == 1 else { return .many(layoutNodes.take()) }
        return .one(layoutNodes.popLast()!)
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
