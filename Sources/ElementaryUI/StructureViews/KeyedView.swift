public struct _KeyedView<Value: View>: View {
    public typealias Tag = Value.Tag
    public typealias _MountedNode = _KeyedNode

    var key: _ViewKey
    var value: Value

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) -> _MountedNode {
        let childRoot = MountRoot.materialized(
            seedContext: context,
            ctx: &ctx,
            create: { context, ctx in
                AnyReconcilable(Value._makeNode(view.value, context: context, ctx: &ctx))
            }
        )
        return .init(
            keys: [view.key],
            children: [childRoot],
            context: context
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
            as: Value._MountedNode.self,
            makeNode: { context, ctx in
                Value._makeNode(view.value, context: context, ctx: &ctx)
            },
            patchNode: { node, tx in
                Value._patchNode(view.value, node: &node, tx: &tx)
            }
        )
    }
}

public extension View {
    func key<K: LosslessStringConvertible>(_ key: K) -> some View<Tag> & _KeyReadableView {
        _KeyedView(key: _ViewKey(key), value: self)
    }
}

public protocol _KeyReadableView: View {
    associatedtype Value: View

    var _key: _ViewKey { get }
    var _value: Value { get }
}

extension _KeyedView: _KeyReadableView {
    public var _key: _ViewKey {
        key
    }

    public var _value: Value {
        value
    }
}
