extension View {
    /// Applies a type-erased transition to this view.
    public func transition(
        _ transition: AnyTransition
    ) -> some View {
        _TransitionView(transition: transition, wrapped: self)
    }

    /// Applies a transition to this view.
    ///
    /// The optional animation becomes the transition's default animation.
    public func transition<T: Transition>(
        _ transition: T,
        animation: Animation? = nil
    ) -> some View {
        self.transition(
            AnyTransition(transition, animation: animation)
        )
    }
}

struct _TransitionView<V: View>: View {
    typealias Content = Never
    var transition: AnyTransition
    var wrapped: V

    typealias _MountedNode = _TransitionNode<V>

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        .init(view: view, context: context, ctx: &ctx)
    }

    static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.patch(view, tx: &tx)
    }
}

// transitions render in their identity phase, which is the content itself
extension _TransitionView: _ServerTransparentContent {
    var _serverContent: V { wrapped }
}
