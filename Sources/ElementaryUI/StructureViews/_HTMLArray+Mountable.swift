extension _HTMLArray: _Mountable, View where Element: View {
    public typealias _MountedNode = _KeyedNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        var keys: [_ViewKey] = []
        let estimatedCount = view.value.underestimatedCount
        keys.reserveCapacity(estimatedCount)

        for (index, _) in view.value.enumerated() {
            keys.append(_ViewKey(String(index)))
        }

        return _MountedNode(
            keys: keys,
            context: context,
            ctx: &ctx,
            makeNode: { index, context, ctx in
                AnyReconcilable(Element._makeNode(view.value[index], context: context, ctx: &ctx))
            }
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        // maybe we can optimize this
        // NOTE: written with cast for this https://github.com/swiftlang/swift/issues/83895
        let indexes = view.value.indices.map { _ViewKey(String($0 as Int)) }

        node.patch(
            indexes,
            context: &tx,
            as: Element._MountedNode.self,
            makeNode: { index, context, ctx in
                Element._makeNode(view.value[index], context: context, ctx: &ctx)
            },
            patchNode: { index, node, tx in
                Element._patchNode(view.value[index], node: &node, tx: &tx)
            }
        )

    }
}
