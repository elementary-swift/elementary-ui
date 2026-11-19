// SVG resolves transform-origin against the viewBox and defaults it to 0 0, so rotate() and scale() would pivot on the canvas corner.
final class SVGTransformBoxModifier: DOMElementModifier {
    typealias Value = Void

    init(value: consuming Void, upstream: borrowing DOMElementModifiers, ctx: inout _MountContext) {}

    func updateValue(_ value: consuming Void, _ context: inout _TransactionContext) {}

    func mount(_ node: DOM.Node, _ context: inout _MountContext) {
        context.dom.setStyleProperty(node, name: "transform-box", value: "fill-box")
        context.dom.setStyleProperty(node, name: "transform-origin", value: "50% 50%")
    }
}
