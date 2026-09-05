// NOTE: SVG resolves transform-origin against the viewBox and defaults it to 0 0, so an
// untouched rotate() or scale() pivots on the canvas corner. These two properties give the
// shared CSS the same meaning it has for HTML.
//
// The transform modifiers own them: they are written into the same inline style as the
// element's own attributes, so setting transform-box or transform-origin by hand on a
// rotated or scaled element is not supported - whichever is written last wins.
final class SVGTransformBoxModifier: DOMElementModifier, Unmountable {
    typealias Value = Void

    init(value: consuming Void, upstream: borrowing DOMElementModifiers) {}

    func updateValue(_ value: consuming Void, _ context: inout _TransactionContext) {}

    func mount(_ node: DOM.Node, _ context: inout _MountContext) -> AnyUnmountable {
        context.dom.setStyleProperty(node, name: "transform-box", value: "fill-box")
        context.dom.setStyleProperty(node, name: "transform-origin", value: "50% 50%")
        return AnyUnmountable(self)
    }

    func unmount(_ context: inout _CommitContext) {}
}
