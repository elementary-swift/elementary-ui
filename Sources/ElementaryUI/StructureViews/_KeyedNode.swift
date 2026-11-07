public struct _KeyedNode: ~Copyable {
    let container: MountContainer

    init<Node: ~Copyable>(
        keys: borrowing Span<_ViewKey>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.container = MountContainer(
            mountedKeyStorage: keys,
            context: context,
            ctx: &ctx,
            makeNode: makeNode
        )
        ctx.appendContainer(container)
    }

    init<Node: ~Copyable>(
        key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.container = MountContainer(
            mountedKey: key,
            context: context,
            ctx: &ctx,
            makeNode: makeNode
        )
        ctx.appendContainer(container)
    }

    mutating func patch(
        key: _ViewKey,
        context: inout _TransactionContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> UniqueAny,
        patchNode: (inout UniqueAny, inout _TransactionContext) -> Void
    ) {
        container.patch(
            key: key,
            tx: &context,
            makeNode: makeNode,
            patchNode: patchNode
        )
    }

    mutating func patch(
        _ newKeys: borrowing Span<_ViewKey>,
        context: inout _TransactionContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> UniqueAny,
        patchNode: (Int, inout UniqueAny, inout _TransactionContext) -> Void
    ) {
        container.patch(
            keys: newKeys,
            tx: &context,
            makeNode: makeNode,
            patchNode: patchNode
        )
    }
}
