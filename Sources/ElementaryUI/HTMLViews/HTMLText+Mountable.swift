extension HTMLText: _Mountable, View {
    public typealias _MountedNode = _TextNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) -> _MountedNode {
        _MountedNode(view.text, viewContext: context, context: &ctx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.patch(view.text, context: &tx)
    }
}
