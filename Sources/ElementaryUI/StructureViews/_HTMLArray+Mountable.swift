extension _HTMLArray: _Mountable, View where Element: View {
    public typealias _MountedNode = _KeyedNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        var keys: [_ViewKey] = []
        let count = view.value.count
        keys.reserveCapacity(count)
        for index in 0..<count {
            keys.append(_ViewKey(index))
        }

        return _MountedNode(
            keys: keys,
            context: context,
            ctx: &ctx,
            makeNode: { index, context, ctx in
                Element._makeNode(view.value[index], context: context, ctx: &ctx)
            }
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        var keys: [_ViewKey] = []
        let count = view.value.count
        keys.reserveCapacity(count)
        for index in 0..<count {
            keys.append(_ViewKey(index))
        }

        node.patch(
            keys,
            context: &tx,
            makeNode: { index, context, ctx in
                AnyReconcilable(
                    Element._makeNode(view.value[index], context: context, ctx: &ctx)
                )
            },
            patchNode: { index, anyNode, tx in
                anyNode.modify(as: Element._MountedNode.self) { node in
                    Element._patchNode(view.value[index], node: &node, tx: &tx)
                }
            }
        )

    }
}
