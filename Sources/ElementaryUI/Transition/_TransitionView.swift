extension View {
    public func transition<T: Transition>(_ transition: T, animation: Animation? = nil) -> _TransitionView<T, Self> {
        _TransitionView(transition: transition, animation: animation, wrapped: self)
    }
}

public struct _TransitionView<T: Transition, V: View>: View {
    public typealias Content = Never
    var transition: T
    var animation: Animation?
    var wrapped: V

    public typealias _MountedNode = _TransitionNode<T, V>

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
        node.patchWrappedContent(view, tx: &tx)
    }
}
