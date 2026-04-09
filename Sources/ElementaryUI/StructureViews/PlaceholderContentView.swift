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
    private var makeNodeFn: (borrowing _ViewContext, inout _MountContext) -> _PlaceholderNode

    init(makeNodeFn: @escaping (borrowing _ViewContext, inout _MountContext) -> _PlaceholderNode) {
        self.makeNodeFn = makeNodeFn
    }
}

extension PlaceholderContentView: _Mountable {
    public typealias _MountedNode = _PlaceholderNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        view.makeNodeFn(context, &ctx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
    }
}

public final class _PlaceholderNode: _Reconcilable {
    var node: AnyReconcilable

    init(node: consuming AnyReconcilable) {
        self.node = node
    }

    public func unmount(_ context: inout _CommitContext) {
        node.unmount(&context)
    }
}
