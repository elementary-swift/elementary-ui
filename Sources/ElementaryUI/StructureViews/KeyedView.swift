public struct _KeyedView<Value: MarkupContent & _Mountable>: _Mountable {
    public typealias Tag = Value.Tag
    public typealias Body = Never
    public typealias _MountedNode = _KeyedNode

    var key: _ViewKey
    var value: Value

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        .init(
            key: view.key,
            context: context,
            ctx: &ctx,
            makeNode: { context, ctx in
                Value._makeNode(view.value, context: context, ctx: &ctx)
            }
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.patch(
            key: view.key,
            context: &tx,
            makeNode: { context, ctx in
                AnyReconcilable(
                    Value._makeNode(view.value, context: context, ctx: &ctx)
                )
            },
            patchNode: { anyNode, tx in
                anyNode.modify(as: Value._MountedNode.self) { node in
                    Value._patchNode(view.value, node: &node, tx: &tx)
                }
            }
        )
    }
}

extension _KeyedView: MarkupContent {}
extension _KeyedView: HTML where Value: HTML {}
extension _KeyedView: View where Value: View {}
extension _KeyedView: SVGContent where Value: SVGView {}
extension _KeyedView: SVGView where Value: SVGView {}

#if !hasFeature(Embedded)
extension _KeyedView: _Renderable {
    public static func _render<Renderer: _HTMLRendering>(
        _ html: consuming Self,
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) {
        Value._render(html.value, into: &renderer, with: context)
    }

    public static func _render<Renderer: _AsyncHTMLRendering>(
        _ html: consuming Self,
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) async throws {
        try await Value._render(html.value, into: &renderer, with: context)
    }
}
#endif

public extension View {
    func key<K: LosslessStringConvertible>(_ key: K) -> some View<Tag> & _KeyReadableView {
        _KeyedView(key: _ViewKey(key), value: self)
    }
}

public extension SVGView {
    func key<K: LosslessStringConvertible>(_ key: K) -> some SVGView<Tag> & _KeyReadableSVGView {
        _KeyedView(key: _ViewKey(key), value: self)
    }
}

public protocol _KeyReadableContent: _Mountable {
    associatedtype Value: MarkupContent & _Mountable

    var _key: _ViewKey { get }
    var _value: Value { get }
}

public protocol _KeyReadableView: _KeyReadableContent, View where Value: View {}

public protocol _KeyReadableSVGView: _KeyReadableContent, SVGView where Value: SVGView {}

extension _KeyedView: _KeyReadableContent {
    public var _key: _ViewKey {
        key
    }

    public var _value: Value {
        value
    }
}

extension _KeyedView: _KeyReadableView where Value: View {}
extension _KeyedView: _KeyReadableSVGView where Value: SVGView {}
