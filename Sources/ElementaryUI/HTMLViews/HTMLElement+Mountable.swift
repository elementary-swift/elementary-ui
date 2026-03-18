extension HTMLElement: _Mountable, View where Content: _Mountable {
    public typealias _MountedNode = _ElementNode<Content._MountedNode>

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
            makeChild: { viewContext, c in Content._makeNode(view.content, context: viewContext, ctx: &c) }
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {

        node.update(attributes: view._attributes, &tx) { child, r in
            Content._patchNode(
                view.content,
                node: &child,
                tx: &r
            )
        }
    }
}
