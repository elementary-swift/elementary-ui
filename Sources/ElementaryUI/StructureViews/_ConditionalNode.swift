private let keyA = _ViewKey(0)
private let keyB = _ViewKey(1)

public struct _ConditionalNode: ~Copyable {
    let container: MountContainer

    init<Node: ~Copyable>(
        isA: Bool,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeActive: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        let initialKey = isA ? keyA : keyB
        self.container = MountContainer(
            mountedKey: initialKey,
            context: context,
            ctx: &ctx,
            makeNode: makeActive
        )
        ctx.appendContainer(container)
    }

    mutating func patchWithA<NodeA: ~Copyable>(
        tx: inout _TransactionContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> NodeA,
        updateNode: (inout NodeA, inout _TransactionContext) -> Void
    ) {
        patchBranch(
            key: keyA,
            tx: &tx,
            makeNode: makeNode,
            updateNode: updateNode
        )
    }

    mutating func patchWithB<NodeB: ~Copyable>(
        tx: inout _TransactionContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> NodeB,
        updateNode: (inout NodeB, inout _TransactionContext) -> Void
    ) {
        patchBranch(
            key: keyB,
            tx: &tx,
            makeNode: makeNode,
            updateNode: updateNode
        )
    }
}

private extension _ConditionalNode {
    mutating func patchBranch<Node: ~Copyable>(
        key: _ViewKey,
        tx: inout _TransactionContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node,
        updateNode: (inout Node, inout _TransactionContext) -> Void
    ) {
        container.patch(
            key: key,
            tx: &tx,
            makeNode: { viewContext, mountCtx in
                UniqueAny(makeNode(viewContext, &mountCtx))
            },
            patchNode: { anyNode, tx in
                updateNode(&anyNode[as: Node.self], &tx)
            }
        )
    }
}
