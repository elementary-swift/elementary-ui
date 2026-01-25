extension HTMLVoidElement: _Mountable, View {
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
                makeChild: { _, _ in AnyReconcilable(_EmptyNode()) }
            )
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.updateValue(view._attributes, &tx)
    }
}
