public struct _ConditionalNode: _Reconcilable {
    // true  → activeRoots[0] holds a NodeA; A occupies originalMountIndex 0, B occupies 1
    // false → activeRoots[0] holds a NodeB
    var isA: Bool
    let viewContext: _ViewContext
    let container: MountRootContainer

    init(isA: Bool, root: MountRoot, context: borrowing _ViewContext, ctx: inout _MountContext) {
        self.isA = isA
        self.viewContext = copy context
        self.container = MountRootContainer(roots: [root])
        container.register(into: &ctx)
    }

    mutating func patchWithA<NodeA: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> NodeA,
        updateNode: (inout NodeA, inout _TransactionContext) -> Void
    ) {
        if isA {
            // A is active (with or without B leaving): patch A in place
            patchRoot(container.activeRoots[0], as: NodeA.self, tx: &tx, updateNode: updateNode)
        } else if container.leavingTracker.entries.isEmpty {
            // B active, nothing leaving → B starts leaving at index 1, new A becomes active
            let newA = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            container.activeRoots[0].startRemoval(&tx, handle: container.containerHandle)
            container.leavingTracker.insert(container.activeRoots[0], atOriginalIndex: 1)
            container.activeRoots[0] = newA
            isA = true
            container.reportLayoutChange(&tx)
        } else {
            // B active, A is leaving at index 0 → restore A, B starts leaving at index 1
            let leavingA = container.leavingTracker.entries[0].value
            patchRoot(leavingA, as: NodeA.self, tx: &tx, updateNode: updateNode)
            leavingA.cancelRemoval(&tx, handle: container.containerHandle)
            container.leavingTracker.entries.remove(at: 0)
            container.activeRoots[0].startRemoval(&tx, handle: container.containerHandle)
            container.leavingTracker.insert(container.activeRoots[0], atOriginalIndex: 1)
            container.activeRoots[0] = leavingA
            isA = true
            container.reportLayoutChange(&tx)
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
        } else if container.leavingTracker.entries.isEmpty {
            // A active, nothing leaving → A starts leaving at index 0, new B becomes active
            let newB = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            container.activeRoots[0].startRemoval(&tx, handle: container.containerHandle)
            container.leavingTracker.insert(container.activeRoots[0], atOriginalIndex: 0)
            container.activeRoots[0] = newB
            isA = false
            container.reportLayoutChange(&tx)
        } else {
            // A active, B is leaving at index 1 → restore B, A starts leaving at index 0
            let leavingB = container.leavingTracker.entries[0].value
            patchRoot(leavingB, as: NodeB.self, tx: &tx, updateNode: updateNode)
            leavingB.cancelRemoval(&tx, handle: container.containerHandle)
            container.leavingTracker.entries.remove(at: 0)
            container.activeRoots[0].startRemoval(&tx, handle: container.containerHandle)
            container.leavingTracker.insert(container.activeRoots[0], atOriginalIndex: 0)
            container.activeRoots[0] = leavingB
            isA = false
            container.reportLayoutChange(&tx)
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
        MountRoot(
            pending: viewContext,
            transaction: transaction,
            transitionPhase: .willAppear,
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
