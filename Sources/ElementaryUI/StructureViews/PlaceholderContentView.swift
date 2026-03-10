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
    private var makeNodeFn: (borrowing _ViewContext, inout _TransactionContext) -> _PlaceholderNode

    init(makeNodeFn: @escaping (borrowing _ViewContext, inout _TransactionContext) -> _PlaceholderNode) {
        self.makeNodeFn = makeNodeFn
    }
}

extension PlaceholderContentView: _Mountable {
    public typealias _MountedNode = _PlaceholderNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        view.makeNodeFn(context, &tx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {}
}

public final class _PlaceholderNode: _Reconcilable {
    var node: AnyReconcilable

    init(node: AnyReconcilable) {
        self.node = node
    }

    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        node.apply(op, &tx)
    }

    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        node.collectChildren(&ops, &context)
    }

    public func unmount(_ context: inout _CommitContext) {
        // TODO: we should maybe remove ourself from the parent list?
        // or at least prevent updates to unmounted placeholders
        node.unmount(&context)
    }
}
