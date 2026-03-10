extension _AttributedElement: _Mountable, View where Content: _Mountable {
    public typealias _MountedNode = _StatefulNode<_AttributeModifier, Content._MountedNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        let attributeModifier = _AttributeModifier(value: view.attributes, upstream: context.modifiers, &tx)

        var context = copy context
        context.modifiers[_AttributeModifier.key] = attributeModifier

        return _MountedNode(
            state: attributeModifier,
            child: Content._makeNode(view.content, context: context, tx: &tx)
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.updateValue(view.attributes, &tx)

        Content._patchNode(
            view.content,
            node: &node.child,
            tx: &tx
        )
    }
}
