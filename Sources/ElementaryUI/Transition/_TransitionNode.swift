final class _TransitionState {
    var value: AnyTransition

    init(_ value: AnyTransition) {
        self.value = value
    }
}

public struct _TransitionNode<V: View>: ~Copyable, _Reconcilable {
    private let transition: _TransitionState
    private var wrappedNode: V._MountedNode

    init(
        view: consuming _TransitionView<V>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        // NOTE: this is for dead code stripping to keep size down if no transitions are used
        _DeferredRemoval.install(type: _TransitionRemoval.self)

        let transition = _TransitionState(view.transition)
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
        _ view: consuming _TransitionView<V>,
        tx: inout _TransactionContext
    ) {
        transition.value = view.transition
        V._patchNode(view.wrapped, node: &wrappedNode, tx: &tx)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        wrappedNode.unmount(&context)
    }
}
