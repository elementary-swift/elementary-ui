import BasicContainers

public struct _TransitionableNode<Node: _Reconcilable & ~Copyable>:
    ~Copyable,
    _Reconcilable
{
    // FIXME: this should be an enum, but 6.3 has serious embedded miscompiles with enums and ownership
    // revisit in 6.4
    private var node: Node?
    private var transitionedElement: _TransitionElement?

    init(
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode:
            @escaping (
                borrowing _ViewContext,
                inout _MountContext
            ) -> Node
    ) {
        defer {
            precondition(node != nil || transitionedElement != nil)
            precondition(node == nil || transitionedElement == nil)
        }

        guard let transition = context.transition else {
            self.node = makeNode(context, &ctx)
            return
        }

        // An element consumes the transition modifier; it must never leak into
        // structural content mounted below that element.
        var nodeContext = copy context
        nodeContext.transition = nil

        // Without a structural owner there is nothing that can defer removal.
        guard ctx.slotTransitions != nil else {
            self.node = makeNode(nodeContext, &ctx)
            return
        }

        self.transitionedElement = _TransitionElement.make(
            transition: transition.value,
            context: nodeContext,
            ctx: &ctx,
            makeElement: { context, ctx in
                AnyReconcilable(makeNode(context, &ctx))
            }
        )
    }

    mutating func update(
        _ tx: inout _TransactionContext,
        body: (inout Node, inout _TransactionContext) -> Void
    ) {
        if node != nil { body(&node!, &tx) }
        if transitionedElement != nil {
            transitionedElement!.forEachPlaceholder { placeholder in
                placeholder.modify(as: Node.self) { node in
                    body(&node, &tx)
                }
            }
        }
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        node.take()?.unmount(&context)
        transitionedElement.take()?.unmount(&context)
    }
}

/// The generic reconciler stores only this base class, keeping its transitioned
/// branches short and preventing specialization of the concrete implementation.
class _TransitionElement {
    var defaultAnimation: Animation? { fatalError("abstract") }
    var isMounted: Bool { fatalError("abstract") }

    private static var type: _TransitionElement.Type? = nil

    static func install(_ type: _TransitionElement.Type) {
        self.type = type
    }

    class func make(
        transition: AnyTransition,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeElement:
            @escaping (
                borrowing _ViewContext,
                inout _MountContext
            ) -> AnyReconcilable
    ) -> _TransitionElement {
        guard let type else { preconditionFailure("No transition element type installed") }
        return type.make(transition: transition, context: context, ctx: &ctx, makeElement: makeElement)
    }

    func patchPhase(
        _ phase: TransitionPhase,
        tx: inout _TransactionContext
    ) {
        fatalError("abstract")
    }

    func forEachPlaceholder(_ body: (inout AnyReconcilable) -> Void) {
        fatalError("abstract")
    }

    func unmount(_ context: inout _CommitContext) {
        fatalError("abstract")
    }
}

/// Owns a mounted transition body and every placeholder where that body mounts
/// its underlying element. Custom transition bodies may omit or duplicate it.
final class _MountedTransitionElement: _TransitionElement {
    private let transition: AnyTransition
    private var bodyNode: AnyReconcilable?
    private var placeholderNode: AnyReconcilable?
    private var additionalPlaceholderNodes: UniqueArray<AnyReconcilable> = .init()
    private var makeElement:
        (
            (
                borrowing _ViewContext,
                inout _MountContext
            ) -> AnyReconcilable
        )?

    override class func make(
        transition: AnyTransition,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeElement:
            @escaping (
                borrowing _ViewContext,
                inout _MountContext
            ) -> AnyReconcilable
    ) -> _TransitionElement {
        _MountedTransitionElement(transition: transition, context: context, ctx: &ctx, makeElement: makeElement)
    }

    @inline(never)
    init(
        transition: AnyTransition,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeElement:
            @escaping (
                borrowing _ViewContext,
                inout _MountContext
            ) -> AnyReconcilable
    ) {
        self.transition = transition
        self.makeElement = makeElement

        let initialPhase = transitionInitialPhase(
            defaultAnimation: transition.animation,
            transaction: ctx.transaction
        )
        super.init()
        self.bodyNode = transition.makeNode(
            phase: initialPhase,
            context: context,
            ctx: &ctx,
            makePlaceholderNode: self.makePlaceholderNode
        )
        ctx.registerTransition(
            self,
            initialPhase: initialPhase
        )
    }

    override var defaultAnimation: Animation? {
        transition.animation
    }

    override var isMounted: Bool {
        bodyNode != nil
    }

    override func patchPhase(
        _ phase: TransitionPhase,
        tx: inout _TransactionContext
    ) {
        guard bodyNode != nil else { return }
        transition.patchNode(
            to: phase,
            node: &bodyNode!,
            tx: &tx,
            makePlaceholderNode: self.makePlaceholderNode
        )
    }

    override func forEachPlaceholder(
        _ body: (inout AnyReconcilable) -> Void
    ) {
        guard placeholderNode != nil else { return }
        body(&placeholderNode!)

        for index in additionalPlaceholderNodes.indices {
            body(&additionalPlaceholderNodes[index])
        }
    }

    override func unmount(_ context: inout _CommitContext) {
        bodyNode?.unmount(&context)
        bodyNode = nil
        placeholderNode = nil
        additionalPlaceholderNodes.removeAll()
        makeElement = nil
    }

    private func makePlaceholderNode(
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        if placeholderNode == nil {
            placeholderNode = makeElement!(context, &ctx)
        } else {
            additionalPlaceholderNodes.append(makeElement!(context, &ctx))
        }
    }
}
