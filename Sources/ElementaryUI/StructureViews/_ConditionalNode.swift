private let keyA = _ViewKey(0)
private let keyB = _ViewKey(1)

public struct _ConditionalNode: _Reconcilable {
    let container: MountRootContainer

    init<Node: _Reconcilable>(
        isA: Bool,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeActive: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.container = MountRootContainer(context: context)
        let initialKey = isA ? keyA : keyB
        container.createInline(key: initialKey, ctx: &ctx, makeNode: makeActive)
        ctx.appendContainer(container)
    }

    mutating func patchWithA<NodeA: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> NodeA,
        updateNode: (inout NodeA, inout _TransactionContext) -> Void
    ) {
        patchBranch(
            key: keyA,
            tx: &tx,
            makeNode: makeNode,
            updateNode: updateNode
        )
    }

    mutating func patchWithB<NodeB: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> NodeB,
        updateNode: (inout NodeB, inout _TransactionContext) -> Void
    ) {
        patchBranch(
            key: keyB,
            tx: &tx,
            makeNode: makeNode,
            updateNode: updateNode
        )
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        container.unmount(&context)
    }
}

private extension _ConditionalNode {
    mutating func patchBranch<Node: _Reconcilable>(
        key: _ViewKey,
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> Node,
        updateNode: (inout Node, inout _TransactionContext) -> Void
    ) {
        container.patch(
            keys: CollectionOfOne(key),
            tx: &tx,
            makeNode: { _, context, mountCtx in
                makeNode(context, &mountCtx)
            },
            patchNode: { _, node, tx in
                updateNode(&node, &tx)
            }
        )
    }
}
