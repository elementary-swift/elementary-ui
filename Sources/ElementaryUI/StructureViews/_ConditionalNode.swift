private let keyA = _ViewKey(0)
private let keyB = _ViewKey(1)

public struct _ConditionalNode: _Reconcilable {
    let container: MountContainer

    init<Node: _Reconcilable>(
        isA: Bool,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeActive: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        let initialKey = isA ? keyA : keyB
        let containerContext = copy context
        self.container = MountContainer(
            mountedKey: initialKey,
            context: consume containerContext,
            ctx: &ctx,
            makeNode: makeActive
        )
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
            key: key,
            tx: &tx,
            makeNode: { viewContext, mountCtx in
                AnyReconcilable(makeNode(viewContext, &mountCtx))
            },
            patchNode: { anyNode, tx in
                anyNode.modify(as: Node.self) { node in
                    updateNode(&node, &tx)
                }
            }
        )
    }
}
