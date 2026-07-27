extension HTMLElement: _Mountable, View where Content: _Mountable {
    public typealias _MountedNode = _TransitionableNode<
        _ElementNode<Content._MountedNode>
    >

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _TransitionableNode(context: context, ctx: &ctx) {
            viewContext,
            ctx in
            _ElementNode(
                tag: self.Tag.name,
                attributes: view._attributes,
                viewContext: viewContext,
                ctx: &ctx,
                makeChild: { viewContext, ctx in
                    Content._makeNode(
                        view.content,
                        context: viewContext,
                        ctx: &ctx
                    )
                }
            )
        }
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {

        node.update(&tx) { element, tx in
            element.update(attributes: view._attributes, &tx) {
                child,
                tx in
                Content._patchNode(
                    view.content,
                    node: &child,
                    tx: &tx
                )
            }
        }
    }

}
