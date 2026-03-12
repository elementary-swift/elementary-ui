final class OpacityModifier: DOMElementModifier {
    typealias Value = CSSOpacity

    let upstream: OpacityModifier?
    let layerNumber: Int

    var value: CSSValueSource<CSSOpacity>

    init(value: consuming Value, upstream: borrowing DOMElementModifiers) {
        self.value = CSSValueSource(value: value)
        self.upstream = upstream[OpacityModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        self.value.updateValue(value, &context)
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        AnyUnmountable(MountedStyleModifier(node, makeLayers(&context), &context))
    }

    private func makeLayers(_ context: inout _CommitContext) -> [CSSValueSource<CSSOpacity>.Instance] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(value.makeInstance())
            return layers
        } else {
            return [value.makeInstance()]
        }
    }
}
