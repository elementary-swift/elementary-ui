extension View {
    /// Applies a type-erased transition to this view.
    public func transition(
        _ transition: AnyTransition
    ) -> _TransitionView<Self> {
        _TransitionView(transition: transition, wrapped: self)
    }

    /// Applies a transition to this view.
    ///
    /// The optional animation becomes the transition's default animation.
    public func transition<T: Transition>(
        _ transition: T,
        animation: Animation? = nil
    ) -> _TransitionView<Self> {
        self.transition(
            AnyTransition(transition, animation: animation)
        )
    }
}

public struct _TransitionView<V: View>: View {
    public typealias Content = Never
    var transition: AnyTransition
    var wrapped: V

    public typealias _MountedNode = _TransitionNode<V>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        .init(view: view, context: context, ctx: &ctx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.patch(view, tx: &tx)
    }
}
