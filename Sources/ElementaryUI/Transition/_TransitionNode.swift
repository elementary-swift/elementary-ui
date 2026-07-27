// TODO-TRANSITION: simplify this, AI is too stupid

final class _AnyTransition {
    private class Box {
        var animation: Animation?

        init(animation: Animation?) {
            self.animation = animation
        }

        func makeNode(
            phase: TransitionPhase,
            context: borrowing _ViewContext,
            ctx: inout _MountContext,
            makePlaceholderNode: @escaping (borrowing _ViewContext, inout _MountContext) -> _PlaceholderNode
        ) -> AnyReconcilable {
            fatalError("override")
        }

        func patchPhase(
            _ phase: TransitionPhase,
            node: inout AnyReconcilable,
            tx: inout _TransactionContext,
            makePlaceholderNode: @escaping (borrowing _ViewContext, inout _MountContext) -> _PlaceholderNode
        ) {
            fatalError("override")
        }

    }

    private final class TypedBox<T: Transition>: Box {
        var transition: T

        init(transition: T, animation: Animation?) {
            self.transition = transition
            super.init(animation: animation)
        }

        override func makeNode(
            phase: TransitionPhase,
            context: borrowing _ViewContext,
            ctx: inout _MountContext,
            makePlaceholderNode: @escaping (borrowing _ViewContext, inout _MountContext) -> _PlaceholderNode
        ) -> AnyReconcilable {
            let placeholder = PlaceholderContentView<T>(makeNodeFn: makePlaceholderNode)
            return AnyReconcilable(
                T.Body._makeNode(
                    transition.body(content: placeholder, phase: phase),
                    context: context,
                    ctx: &ctx
                )
            )
        }

        override func patchPhase(
            _ phase: TransitionPhase,
            node: inout AnyReconcilable,
            tx: inout _TransactionContext,
            makePlaceholderNode: @escaping (borrowing _ViewContext, inout _MountContext) -> _PlaceholderNode
        ) {
            let placeholder = PlaceholderContentView<T>(makeNodeFn: makePlaceholderNode)
            node.modify(as: T.Body._MountedNode.self) { node in
                T.Body._patchNode(
                    transition.body(content: placeholder, phase: phase),
                    node: &node,
                    tx: &tx
                )
            }
        }

    }

    private let box: Box

    var animation: Animation? {
        box.animation
    }

    private init(box: Box) {
        self.box = box
    }

    static func make<T: Transition>(
        _ transition: T,
        animation: Animation?
    ) -> _AnyTransition {
        _AnyTransition(
            box: TypedBox(transition: transition, animation: animation)
        )
    }

    func update<T: Transition>(_ transition: T, animation: Animation?) {
        guard let box = box as? TypedBox<T> else {
            preconditionFailure("transition type changed while patching")
        }
        box.transition = transition
        box.animation = animation
    }

    func makeNode(
        phase: TransitionPhase,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makePlaceholderNode: @escaping (borrowing _ViewContext, inout _MountContext) -> _PlaceholderNode
    ) -> AnyReconcilable {
        box.makeNode(
            phase: phase,
            context: context,
            ctx: &ctx,
            makePlaceholderNode: makePlaceholderNode
        )
    }

    func patchPhase(
        _ phase: TransitionPhase,
        node: inout AnyReconcilable,
        tx: inout _TransactionContext,
        makePlaceholderNode: @escaping (borrowing _ViewContext, inout _MountContext) -> _PlaceholderNode
    ) {
        box.patchPhase(
            phase,
            node: &node,
            tx: &tx,
            makePlaceholderNode: makePlaceholderNode
        )
    }

}

public struct _TransitionNode<T: Transition, V: View>: ~Copyable, _Reconcilable {
    private let transition: _AnyTransition
    private var wrappedNode: V._MountedNode

    init(
        view: consuming _TransitionView<T, V>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        ctx.scheduler.installTransitionRemoval()

        let transition = _AnyTransition.make(
            view.transition,
            animation: view.animation
        )
        var context = copy context
        context.transition = transition

        self.transition = transition
        self.wrappedNode = V._makeNode(
            view.wrapped,
            context: context,
            ctx: &ctx
        )
    }

    mutating func patch(
        _ view: consuming _TransitionView<T, V>,
        tx: inout _TransactionContext
    ) {
        transition.update(view.transition, animation: view.animation)
        V._patchNode(view.wrapped, node: &wrappedNode, tx: &tx)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        wrappedNode.unmount(&context)
    }
}
