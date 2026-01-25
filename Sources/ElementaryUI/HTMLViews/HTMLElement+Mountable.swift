extension HTMLElement: _Mountable, View where Content: _Mountable {
    public typealias _MountedNode = _StatefulNode<_AttributeModifier, _ElementNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        let attributeModifier = _AttributeModifier(value: view._attributes, upstream: context.modifiers, &tx)

        var context = copy context
        context.modifiers[_AttributeModifier.key] = attributeModifier

        return _MountedNode(
            state: attributeModifier,
            child: _ElementNode(
                tag: self.Tag.name,
                viewContext: context,
                tx: &tx,
                makeChild: { viewContext, r in AnyReconcilable(Content._makeNode(view.content, context: viewContext, tx: &r)) }
            )
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.updateValue(view._attributes, &tx)

        node.child.updateChild(&tx, as: Content._MountedNode.self) { child, r in
            Content._patchNode(
                view.content,
                node: child,
                tx: &r
            )
        }
    }
}
