extension Group: View where Content: View {}
extension Group: _Mountable where Content: _Mountable {
    public typealias _MountedNode = Self.Content._MountedNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) -> _MountedNode {
        Content._makeNode(view.content, context: context, ctx: &ctx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        Content._patchNode(view.content, node: &node, tx: &tx)
    }
}
