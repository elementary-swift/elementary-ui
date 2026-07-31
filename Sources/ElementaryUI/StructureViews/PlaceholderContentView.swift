/// A placeholder view that represents content being transformed by a transition or modifier.
///
/// `PlaceholderContentView` is used internally by the framework when implementing
/// transitions and view modifiers.
///
/// ## Usage in Transitions
///
/// ```swift
/// struct MyTransition: Transition {
///     func body(content: Content, phase: TransitionPhase) -> some View {
///         content  // Content is a PlaceholderContentView<MyTransition>
///             .opacity(phase.isIdentity ? 1 : 0)
///     }
/// }
/// ```
public struct PlaceholderContentView<Value>: View {
    private var makeNodeFn: (borrowing _ViewContext, inout _MountContext) -> Void

    init(makeNodeFn: @escaping (borrowing _ViewContext, inout _MountContext) -> Void) {
        self.makeNodeFn = makeNodeFn
    }
}

extension PlaceholderContentView: _Mountable {
    public typealias _MountedNode = _EmptyNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        view.makeNodeFn(context, &ctx)
        return _EmptyNode()
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
    }
}
