public struct _TransitionableNode<Node: ~Copyable>:
    ~Copyable
{
    // NOTE: this looks like it should be an enum, but that causes code size bloat
    // Spelled out, these have no implicit nil default: init assigns each once
    // instead of destroying a default first (code size, per specialization).
    private var node: Optional<Node>
    private var transitionedElement: Optional<_TransitionElement>

    init<Content: _Mountable>(
        _ value: consuming Content,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) where Content._MountedNode == Node {
        defer {
            assert(node != nil || transitionedElement != nil)
            assert(node == nil || transitionedElement == nil)
        }

        guard let transition = context.transition else {
            self.node = Content._makeNode(value, context: context, ctx: &ctx)
            self.transitionedElement = nil
            return
        }

        // An element consumes the transition modifier; it must never leak into
        // structural content mounted below that element.
        let nodeContext = context.withoutTransition()

        // Without a structural owner there is nothing that can defer removal.
        guard ctx.slotTransitions != nil else {
            self.node = Content._makeNode(value, context: nodeContext, ctx: &ctx)
            self.transitionedElement = nil
            return
        }

        self.node = nil
        self.transitionedElement = _TransitionElement.make(
            transition: transition.value,
            context: nodeContext,
            ctx: &ctx,
            content: PlaceholderContent.make(value)
        )
    }

    mutating func update<Content: _Mountable>(
        _ value: consuming Content,
        _ tx: inout _TransactionContext
    ) where Content._MountedNode == Node {
        if node != nil {
            Content._patchNode(value, node: &node!, tx: &tx)
        } else if let transitionedElement {
            transitionedElement.content.update(value, tx: &tx)
        }
    }
}

/// The generic reconciler stores only this base class, keeping its transitioned
/// branches short and preventing specialization of the concrete implementation.
class _TransitionElement {
    let content: PlaceholderContent

    init(content: PlaceholderContent) { self.content = content }

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
        content: PlaceholderContent
    ) -> _TransitionElement {
        guard let type else { preconditionFailure("No transition element type installed") }
        return type.make(transition: transition, context: context, ctx: &ctx, content: content)
    }

    func patchPhase(
        _ phase: TransitionPhase,
        tx: inout _TransactionContext
    ) {
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
        content: PlaceholderContent
    ) -> _TransitionElement {
        _MountedTransitionElement(transition: transition, context: context, ctx: &ctx, content: content)
    }

    @inline(never)
    init(
        transition: AnyTransition,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        content: PlaceholderContent
    ) {
        self.transition = transition

        let initialPhase = transitionInitialPhase(
            defaultAnimation: transition.animation,
            transaction: ctx.transaction
        )
        super.init(content: content)
        self.bodyNode = transition.makeNode(
            phase: initialPhase,
            context: context,
            ctx: &ctx,
            content: content
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
            content: content
        )
    }
}
