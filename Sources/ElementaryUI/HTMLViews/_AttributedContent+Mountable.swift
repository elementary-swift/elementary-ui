extension _AttributedContent: View where Content: View {}
extension _AttributedContent: SVGView where Content: SVGView {}
extension _AttributedContent: _Mountable where Content: _Mountable {
    public typealias _MountedNode = _StatefulNode<_AttributedContentState, Content._MountedNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        let attributeModifier = AttributeModifier(value: view._attributes, upstream: context.modifiers, ctx: &ctx)

        var context = copy context
        context.modifiers[AttributeModifier.key] = attributeModifier

        let child = Content._makeNode(view.content, context: context, ctx: &ctx)
        return _MountedNode(state: _AttributedContentState(modifier: attributeModifier), child: child)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.modifier.updateValue(view._attributes, &tx)

        Content._patchNode(
            view.content,
            node: &node.child,
            tx: &tx
        )
    }
}
