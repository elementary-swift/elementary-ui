// TODO: replace this with a ModifiedContent struct eventually
struct DOMEffectView<Effect: DOMElementModifier, Wrapped: MarkupContent & _Mountable> {
    typealias Body = Never
    typealias Tag = Wrapped.Tag
    var value: Effect.Value
    var wrapped: Wrapped

    typealias _MountedNode = _StatefulNode<Effect, Wrapped._MountedNode>

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        let effect = Effect(value: view.value, upstream: context.modifiers)

        var context = copy context
        context.modifiers[Effect.key] = effect

        return .init(state: effect, child: Wrapped._makeNode(view.wrapped, context: context, ctx: &ctx))
    }

    static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.updateValue(view.value, &tx)
        Wrapped._patchNode(view.wrapped, node: &node.child, tx: &tx)
    }
}

// MarkupContent must be unconditional: HTML and SVGContent both inherit it, and a
// type conforms to a protocol only once.
extension DOMEffectView: _Mountable {}
extension DOMEffectView: MarkupContent {}
extension DOMEffectView: HTML, View where Wrapped: View {}
extension DOMEffectView: SVGContent, SVGView where Wrapped: SVGView {}
