extension _HTMLArray: _Mountable, View where Element: View {
    public typealias _MountedNode = _KeyedNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) -> _MountedNode {
        var keys: [_ViewKey] = []
        var children: [MountRoot] = []
        let estimatedCount = view.value.underestimatedCount
        keys.reserveCapacity(estimatedCount)
        children.reserveCapacity(estimatedCount)

        for (index, element) in view.value.enumerated() {
            keys.append(_ViewKey(String(index)))
            let root = MountRoot.materialized(
                seedContext: context,
                ctx: &ctx,
                create: { context, ctx in
                    AnyReconcilable(Element._makeNode(element, context: context, ctx: &ctx))
                }
            )
            children.append(root)
        }

        return _MountedNode(keys: keys, children: children, context: context)
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
