public struct _KeyedNode: _Reconcilable {
    let container: MountContainer

    init<Node: _Reconcilable>(
        keys: some Collection<_ViewKey>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        let containerContext = copy context
        self.container = MountContainer(
            mountedKeys: keys,
            context: consume containerContext,
            ctx: &ctx,
            makeNode: makeNode
        )
        ctx.appendContainer(container)
    }

    init<Node: _Reconcilable>(
        key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        let containerContext = copy context
        self.container = MountContainer(
            mountedKey: key,
            context: consume containerContext,
            ctx: &ctx,
            makeNode: makeNode
        )
        ctx.appendContainer(container)
    }

    mutating func patch(
        key: _ViewKey,
        context: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        container.patch(
            key: key,
            tx: &context,
            makeNode: makeNode,
            patchNode: patchNode
        )
    }

    mutating func patch(
        _ newKeys: some BidirectionalCollection<_ViewKey>,
        context: inout _TransactionContext,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (Int, AnyReconcilable, inout _TransactionContext) -> Void
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
