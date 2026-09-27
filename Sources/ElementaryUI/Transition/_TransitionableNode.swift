public struct _TransitionableNode<Node: _Reconcilable & ~Copyable>:
    ~Copyable,
    _Reconcilable
{
    // FIXME: this should be an enum, but 6.3 has serious embedded miscompiles with enums and ownership
    // revisit in 6.4
    private var node: Node?
    private var transitionedElement: _TransitionElement?

    init<Content: _Mountable>(
        _ value: consuming Content,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) where Content._MountedNode == Node {
        defer {
            precondition(node != nil || transitionedElement != nil)
            precondition(node == nil || transitionedElement == nil)
        }

        guard let transition = context.transition else {
            self.node = Content._makeNode(value, context: context, ctx: &ctx)
            return
        }

        // An element consumes the transition modifier; it must never leak into
        // structural content mounted below that element.
        var nodeContext = copy context
        nodeContext.transition = nil

        // Without a structural owner there is nothing that can defer removal.
        guard ctx.slotTransitions != nil else {
            self.node = Content._makeNode(value, context: nodeContext, ctx: &ctx)
            return
        }

        self.transitionedElement = _TransitionElement.make(
            transition: transition.value,
            context: nodeContext,
            ctx: &ctx,
            host: _PlaceholderHost.make(value)
        )
    }

    mutating func update<Content: _Mountable>(
        _ value: Content,
        _ tx: inout _TransactionContext
    ) where Content._MountedNode == Node {
        if node != nil { Content._patchNode(value, node: &node!, tx: &tx) }
        if let transitionedElement {
            transitionedElement.host.update(value, tx: &tx) { node, tx in
                Content._patchNode(value, node: &node, tx: &tx)
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
    let host: _PlaceholderHost

    init(host: _PlaceholderHost) { self.host = host }

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
        host: _PlaceholderHost
    ) -> _TransitionElement {
        guard let type else { preconditionFailure("No transition element type installed") }
        return type.make(transition: transition, context: context, ctx: &ctx, host: host)
    }

    func patchPhase(
        _ phase: TransitionPhase,
        tx: inout _TransactionContext
    ) {
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

    override class func make(
        transition: AnyTransition,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        host: _PlaceholderHost
    ) -> _TransitionElement {
        _MountedTransitionElement(transition: transition, context: context, ctx: &ctx, host: host)
    }

    @inline(never)
    init(
        transition: AnyTransition,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        host: _PlaceholderHost
    ) {
        self.transition = transition

        let initialPhase = transitionInitialPhase(
            defaultAnimation: transition.animation,
            transaction: ctx.transaction
        )
        super.init(host: host)
        self.bodyNode = transition.makeNode(
            phase: initialPhase,
            context: context,
            ctx: &ctx,
            host: host
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
            host: host
        )
    }

    override func unmount(_ context: inout _CommitContext) {
        bodyNode.take()?.unmount(&context)
        host.unmount(&context)
    }
}
