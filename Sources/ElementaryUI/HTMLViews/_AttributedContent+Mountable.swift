extension _AttributedContent: View where Content: View {}
extension _AttributedContent: SVGView where Content: SVGView {}
extension _AttributedContent: _Mountable where Content: _Mountable {
    public typealias _MountedNode = _StatefulNode<_AttributeModifier, Content._MountedNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        let attributeModifier = _AttributeModifier(value: view._attributes, upstream: context.modifiers)

        var context = copy context
        context.modifiers[_AttributeModifier.key] = attributeModifier

        return _MountedNode(
            state: attributeModifier,
            child: Content._makeNode(view.content, context: context, ctx: &ctx)
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.updateValue(view._attributes, &tx)

        Content._patchNode(
            view.content,
            node: &node.child,
            tx: &tx
        )
    }
}
