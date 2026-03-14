public struct _KeyedNode: _Reconcilable {
    let container: MountRootContainer

    init<Node: _Reconcilable>(
        keys: [_ViewKey],
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.container = MountRootContainer(context: context)
        container.mount(keys: keys, ctx: &ctx, makeNode: makeNode)
        ctx.appendContainer(container)
    }

    init<Node: _Reconcilable>(
        key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.init(
            keys: [key],
            context: context,
            ctx: &ctx,
            makeNode: { _, context, ctx in makeNode(context, &ctx) }
        )
    }

    mutating func patch<Node: _Reconcilable>(
        key: _ViewKey,
        context: inout _TransactionContext,
        as: Node.Type = Node.self,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> Node,
        patchNode: (inout Node, inout _TransactionContext) -> Void
    ) {
        patch(
            CollectionOfOne(key),
            context: &context,
            makeNode: { _, context, ctx in makeNode(context, &ctx) },
            patchNode: { _, node, tx in patchNode(&node, &tx) }
        )
    }

    mutating func patch<Node: _Reconcilable>(
        _ newKeys: some BidirectionalCollection<_ViewKey>,
        context: inout _TransactionContext,
        as type: Node.Type = Node.self,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> Node,
        patchNode: (Int, inout Node, inout _TransactionContext) -> Void
    ) {
        _ = type
        container.patch(
            keys: newKeys,
            tx: &context,
            makeNode: makeNode,
            patchNode: patchNode
        )
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        container.unmount(&context)
    }
}
