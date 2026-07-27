extension HTMLVoidElement: _Mountable, View {
    public typealias _MountedNode = _TransitionableNode<
        _ElementNode<_EmptyNode>
    >

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _TransitionableNode(context: context, ctx: &ctx) {
            viewContext, ctx in
            _ElementNode(
                tag: self.Tag.name,
                attributes: view._attributes,
                viewContext: viewContext,
                ctx: &ctx,
                makeChild: { _, _ in _EmptyNode() }
            )
        }
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.update(&tx) { element, tx in
            element.update(attributes: view._attributes, &tx) { _, _ in }
        }
    }

}
