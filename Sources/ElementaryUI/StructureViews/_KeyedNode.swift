public struct _KeyedNode: ~Copyable, _Reconcilable {
    let container: MountContainer

    init<Node: _Reconcilable & ~Copyable>(
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

    init<Node: _Reconcilable & ~Copyable>(
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
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (inout AnyReconcilable, inout _TransactionContext) -> Void
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
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (Int, inout AnyReconcilable, inout _TransactionContext) -> Void
    ) {
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
