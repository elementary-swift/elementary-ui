public struct _ConditionalNode: _Reconcilable {
    // true  → activeRoots[0] holds a NodeA; A occupies originalMountIndex 0, B occupies 1
    // false → activeRoots[0] holds a NodeB
    var isA: Bool
    let viewContext: _ViewContext
    let container: MountRootContainer

    init<Node: _Reconcilable>(
        isA: Bool,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeActive: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.isA = isA
        self.viewContext = copy context
        self.container = MountRootContainer(roots: [])
        let transaction = ctx.inheritedTransaction
        let root = container.makeEagerRoot(
            context: context,
            transaction: transaction,
            ctx: &ctx,
            create: { context, mountCtx in AnyReconcilable(makeActive(context, &mountCtx)) }
        )
        container.activeRoots = [root]
        ctx.appendContainer(container)
    }

    mutating func patchWithA<NodeA: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> NodeA,
        updateNode: (inout NodeA, inout _TransactionContext) -> Void
    ) {
        if isA {
            // A is active (with or without B leaving): patch A in place
            patchRoot(container.activeRoots[0], as: NodeA.self, tx: &tx, updateNode: updateNode)
        } else if !container.hasLeavingRoots {
            // B active, nothing leaving → B starts leaving at index 1, new A becomes active
            let newA = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            container.replaceActiveRoot(at: 0, with: newA, removedOriginalIndex: 1, tx: &tx)
            isA = true
        } else {
            // B active, A is leaving at index 0 → restore A, B starts leaving at index 1
            container.restoreLeavingRootToActive(
                leavingIndex: 0,
                activeIndex: 0,
                activeOriginalIndex: 1,
                tx: &tx
            )
            patchRoot(container.activeRoots[0], as: NodeA.self, tx: &tx, updateNode: updateNode)
            isA = true
        }
    }

    mutating func patchWithB<NodeB: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> NodeB,
        updateNode: (inout NodeB, inout _TransactionContext) -> Void
    ) {
        if !isA {
            // B is active (with or without A leaving): patch B in place
            patchRoot(container.activeRoots[0], as: NodeB.self, tx: &tx, updateNode: updateNode)
        } else if !container.hasLeavingRoots {
            // A active, nothing leaving → A starts leaving at index 0, new B becomes active
            let newB = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            container.replaceActiveRoot(at: 0, with: newB, removedOriginalIndex: 0, tx: &tx)
            isA = false
        } else {
            // A active, B is leaving at index 1 → restore B, A starts leaving at index 0
            container.restoreLeavingRootToActive(
                leavingIndex: 0,
                activeIndex: 0,
                activeOriginalIndex: 0,
                tx: &tx
            )
            patchRoot(container.activeRoots[0], as: NodeB.self, tx: &tx, updateNode: updateNode)
            isA = false
        }
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        container.unmount(&context)
    }
}

private extension _ConditionalNode {
    func makePendingRoot<Node: _Reconcilable>(
        transaction: Transaction,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> Node
    ) -> MountRoot {
        container.makePendingEnteringRoot(
            context: viewContext,
            transaction: transaction,
            create: { context, mountCtx in AnyReconcilable(makeNode(context, &mountCtx)) }
        )
    }

    func patchRoot<Node: _Reconcilable>(
        _ root: MountRoot,
        as _: Node.Type = Node.self,
        tx: inout _TransactionContext,
        updateNode: (inout Node, inout _TransactionContext) -> Void
    ) {
        precondition(!root.isPending, "double patch of pending MountRoot in _ConditionalNode")
        let patched = root.withMountedNode(as: Node.self) { node in updateNode(&node, &tx) }
        precondition(patched, "expected mounted conditional branch")
    }
}
