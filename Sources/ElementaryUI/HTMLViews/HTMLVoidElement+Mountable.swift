extension HTMLVoidElement: _Mountable, View {
    public typealias _MountedNode = _ElementNode<_EmptyNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _ElementNode(
            tag: self.Tag.name,
            attributes: view._attributes,
            viewContext: context,
            ctx: &ctx,
            makeChild: { _, _ in _EmptyNode() }
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.update(attributes: view._attributes, &tx) { _, _ in }
    }
}
