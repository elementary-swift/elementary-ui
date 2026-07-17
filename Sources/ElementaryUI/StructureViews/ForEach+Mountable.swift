extension ForEach: View where Content: _KeyReadableView, Data: Collection {}
extension ForEach: SVGView where Content: _KeyReadableSVGView, Data: Collection {}
extension ForEach: _Mountable where Content: _KeyReadableContent, Data: Collection {
    public typealias _MountedNode = _ForEachNode<Data, Content>

    public init<V: MarkupContent & _Mountable>(
        _ data: Data,
        @ContentBuilder content: @escaping @Sendable (Data.Element) -> V
    ) where Content == _KeyedView<V>, Data.Element: Identifiable, Data.Element.ID: LosslessStringConvertible {
        self.init(
            data,
            content: { _KeyedView(key: _ViewKey($0.id), value: content($0)) }
        )
    }

    public init<ID: LosslessStringConvertible, V: MarkupContent & _Mountable>(
        _ data: Data,
        key: @escaping @Sendable (Data.Element) -> ID,
        @ContentBuilder content: @escaping @Sendable (Data.Element) -> V
    ) where Content == _KeyedView<V> {
        self.init(
            data,
            content: {
                _KeyedView(key: _ViewKey(key($0)), value: content($0))
            }
        )
    }

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(
            data: view._data,
            contentBuilder: view._contentBuilder,
            context: context,
            ctx: &ctx
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.patch(data: view._data, contentBuilder: view._contentBuilder, tx: &tx)
    }
}
