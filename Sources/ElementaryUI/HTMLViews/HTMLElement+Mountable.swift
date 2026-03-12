extension HTMLElement: _Mountable, View where Content: _Mountable {
    public typealias _MountedNode = _StatefulNode<_AttributeModifier, _ElementNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) -> _MountedNode {
        let attributeModifier = _AttributeModifier(value: view._attributes, upstream: context.modifiers)

        var context = copy context
        context.modifiers[_AttributeModifier.key] = attributeModifier

        return _MountedNode(
            state: attributeModifier,
            child: _ElementNode(
                tag: self.Tag.name,
                viewContext: context,
                ctx: &ctx,
                makeChild: { viewContext, c in AnyReconcilable(Content._makeNode(view.content, context: viewContext, ctx: &c)) }
            )
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.updateValue(view._attributes, &tx)

        node.child.updateChild(&tx, as: Content._MountedNode.self) { child, r in
            Content._patchNode(
                view.content,
                node: &child,
                tx: &r
            )
        }
    }
}
