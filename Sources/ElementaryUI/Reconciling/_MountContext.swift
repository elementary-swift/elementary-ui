import BasicContainers
import ContainersPreview
import SpanPreview

/// Shared scratch for everything a mount collects before handing it to its
/// owner. Contexts append at the end; each owner (element, slot, root) moves
/// out the suffix it opened, so nested mounts never allocate here.
struct MountScratch: ~Copyable {
    fileprivate var layoutNodes = UniqueArray<LayoutNode>(minimumCapacity: 16)
    fileprivate var members = UniqueArray<SlotMember>(minimumCapacity: 16)

    var isEmpty: Bool {
        layoutNodes.isEmpty && members.isEmpty
    }
}

/// Mounts into the shared scratch.
///
/// Layout nodes belong to the context that collects them: an element's
/// children, a slot, or the root. Members belong to the enclosing slot (or
/// the root), so an element's children keep the mark of their parent.
public struct _MountContext: ~Copyable, ~Escapable {
    private var scratch: _MutableRef<MountScratch>
    private let layoutStart: Int
    private let membersStart: Int

    /// Only a slot's top level may hold transition elements: a slot is what
    /// defers its removal while they play.
    let acceptsTransitions: Bool
    private(set) var isStatic: Bool = true

    let scheduler: Scheduler
    let dom: DOMInteractor
    let currentFrameTime: Double
    let transaction: Transaction

    /// A root context: owns everything it collects.
    @_lifetime(copy scratch)
    init(
        scratch: consuming _MutableRef<MountScratch>,
        dom: DOMInteractor,
        scheduler: Scheduler,
        currentFrameTime: Double,
        transaction: Transaction
    ) {
        self.layoutStart = scratch.value.layoutNodes.count
        self.membersStart = scratch.value.members.count
        self.scratch = scratch
        self.acceptsTransitions = false
        self.dom = dom
        self.scheduler = scheduler
        self.currentFrameTime = currentFrameTime
        self.transaction = transaction
    }

    @_lifetime(copy scratch)
    private init(
        scratch: consuming _MutableRef<MountScratch>,
        membersStart: Int,
        acceptsTransitions: Bool,
        dom: DOMInteractor,
        scheduler: Scheduler,
        currentFrameTime: Double,
        transaction: Transaction
    ) {
        self.layoutStart = scratch.value.layoutNodes.count
        self.membersStart = membersStart
        self.scratch = scratch
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
        scratch.value.members.append(.unmountable(entry))
    }

    mutating func registerTransition(_ element: _TransitionElement) {
        precondition(acceptsTransitions)
        scratch.value.members.append(.transition(element))
    }

    // MARK: nested contexts

    /// A context for an element's children. Finish it with `mountInDOMNode`.
    @_lifetime(&self)
    mutating func childContext() -> _MountContext {
        nested(membersStart: membersStart, acceptsTransitions: false)
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
        var slotCtx = nested(
            membersStart: scratch.value.members.count,
            acceptsTransitions: true
        )
        let node = makeNode(newKeyIndex, env, &slotCtx)
        return slotCtx.finishSlot(key: key, node: node)
    }

    @_lifetime(&self)
    private mutating func nested(
        membersStart: Int,
        acceptsTransitions: Bool
    ) -> _MountContext {
        let dom = dom
        let scheduler = scheduler
        let currentFrameTime = currentFrameTime
        let transaction = transaction
        return _MountContext(
            scratch: _MutableRef(&scratch.value),
            membersStart: membersStart,
            acceptsTransitions: acceptsTransitions,
            dom: dom,
            scheduler: scheduler,
            currentFrameTime: currentFrameTime,
            transaction: transaction
        )
    }

    // MARK: finishing

    private consuming func finishSlot(
        key: _ViewKey,
        node: consuming AnyReconcilable
    ) -> MountContainer.Slot {
        let members = takeMembers()
        return MountContainer.Slot(
            key: key,
            node: node,
            layoutNodes: takeSlotLayoutNodes(),
            members: members
        )
    }

    /// Mounts the root's layout into `domNode` and hands over its members.
    consuming func mountRoot(in domNode: DOM.Node) -> SlotMembers {
        mountLayout(in: domNode, observers: [], ownsAllChildren: false)
        return takeMembers()
    }

    /// Mounts an element's children into `domNode`. Their members stay with
    /// the enclosing slot.
    consuming func mountInDOMNode(
        _ domNode: DOM.Node,
        observers: [DOMLayoutObserver] = []
    ) {
        mountLayout(in: domNode, observers: observers, ownsAllChildren: true)
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
            scratch.value.layoutNodes.consumeLast(layoutCount) { span in
                for index in span.indices {
                    dom.appendChild(span[unchecked: index].staticDOMNode, to: domNode)
                }
            }
            return
        }

        let container = LayoutContainer(
            domNode: domNode,
            scheduler: scheduler,
            layoutNodes: takeLayoutNodes(),
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

    private var layoutCount: Int {
        scratch.value.layoutNodes.count - layoutStart
    }

    private mutating func takeLayoutNodes() -> RigidArray<LayoutNode> {
        var result = RigidArray<LayoutNode>(capacity: layoutCount)
        scratch.value.layoutNodes.consumeLast(layoutCount) { span in
            result.append(moving: &span)
        }
        return result
    }

    private mutating func takeSlotLayoutNodes() -> SlotLayoutNodes {
        guard layoutCount == 1 else { return .many(takeLayoutNodes()) }
        return .one(scratch.value.layoutNodes.popLast()!)
    }

    private mutating func takeMembers() -> SlotMembers {
        let count = scratch.value.members.count - membersStart
        guard count > 0 else { return SlotMembers() }
        var members: SlotMembers?
        scratch.value.members.consumeLast(count) { span in
            members = SlotMembers(moving: &span)
        }
        return members.take()!
    }

    private mutating func appendLayoutNode(_ node: LayoutNode) {
        isStatic = isStatic && node.isStatic
        scratch.value.layoutNodes.append(node)
    }

    deinit {
        // finishing moves the layout nodes out; anything left would leak into
        // the enclosing context's layout
        assert(layoutCount == 0, "mount context dropped without finishing")
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
