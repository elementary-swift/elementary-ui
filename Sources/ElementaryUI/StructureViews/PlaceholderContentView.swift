/// A placeholder view that represents content being transformed by a transition or modifier.
///
/// `PlaceholderContentView` is used internally by the framework when implementing
/// transitions and view modifiers.
public struct PlaceholderContentView<Value>: View {
    let content: PlaceholderContent

    init(content: PlaceholderContent) { self.content = content }
}

extension PlaceholderContentView: _Mountable {
    public typealias _MountedNode = _PlaceholderNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _PlaceholderNode(host: view.content, context: context, ctx: &ctx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
    }
}

public struct _PlaceholderNode: ~Copyable, _Reconcilable {
    private let host: PlaceholderContent
    private let id: PlaceholderContent.InstanceID

    init(host: PlaceholderContent, context: borrowing _ViewContext, ctx: inout _MountContext) {
        self.host = host
        self.id = host.mountInstance(context: context, ctx: &ctx)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        host.unmountInstance(id, &context)
    }
}
