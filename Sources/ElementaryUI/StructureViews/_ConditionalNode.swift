public final class _ConditionalNode: _Reconcilable, DynamicNode {
    enum State {
        case a(MountRoot)
        case b(MountRoot)
        case aWithBLeaving(MountRoot, MountRoot)
        case bWithALeaving(MountRoot, MountRoot)
    }

    private var state: State
    private var context: _ViewContext
    private var containerHandle: LayoutContainer.Handle?

    var count: Int {
        switch state {
        case .a, .b:
            1
        case .aWithBLeaving, .bWithALeaving:
            2
        }
    }

    init(state: State, context: borrowing _ViewContext, ctx: inout _MountContext) {
        self.state = state
        self.context = copy context
        ctx.appendDynamicNode(self)
    }

    final func patchWithA<NodeA: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> NodeA,
        updateNode: (inout NodeA, inout _TransactionContext) -> Void
    ) {
        var didStructureChange = false

        switch state {
        case .a(let a):
            patchActiveRoot(a, tx: &tx, updateNode: updateNode)
            state = .a(a)
        case .b(let b):
            let a = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            b.startRemoval(&tx, handle: containerHandle)
            state = .aWithBLeaving(a, b)
            didStructureChange = true
        case .aWithBLeaving(let a, let b):
            patchActiveRoot(a, tx: &tx, updateNode: updateNode)
            state = .aWithBLeaving(a, b)
        case .bWithALeaving(let b, let a):
            patchActiveRoot(a, tx: &tx, updateNode: updateNode)
            a.cancelRemoval(&tx, handle: containerHandle)
            b.startRemoval(&tx, handle: containerHandle)
            state = .aWithBLeaving(a, b)
            didStructureChange = true
        }

        if didStructureChange {
            containerHandle?.reportLayoutChange(&tx)
        }
    }

    final func patchWithB<NodeB: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> NodeB,
        updateNode: (inout NodeB, inout _TransactionContext) -> Void
    ) {
        var didStructureChange = false

        switch state {
        case .b(let b):
            patchActiveRoot(b, tx: &tx, updateNode: updateNode)
            state = .b(b)
        case .a(let a):
            let b = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            a.startRemoval(&tx, handle: containerHandle)
            state = .bWithALeaving(b, a)
            didStructureChange = true
        case .aWithBLeaving(let a, let b):
            patchActiveRoot(b, tx: &tx, updateNode: updateNode)
            state = .bWithALeaving(b, a)
        case .bWithALeaving(let b, let a):
            patchActiveRoot(b, tx: &tx, updateNode: updateNode)
            state = .bWithALeaving(b, a)
        }

        if didStructureChange {
            containerHandle?.reportLayoutChange(&tx)
        }
    }

    private final func makePendingRoot<Node: _Reconcilable>(
        transaction: Transaction,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> Node
    ) -> MountRoot {
        MountRoot(
            pending: context,
            transaction: transaction,
            transitionPhase: .willAppear,
            create: { viewContext, mountCtx in
                AnyReconcilable(makeNode(viewContext, &mountCtx))
            }
        )
    }

    private final func patchActiveRoot<Node: _Reconcilable>(
        _ root: MountRoot,
        tx: inout _TransactionContext,
        updateNode: (inout Node, inout _TransactionContext) -> Void
    ) {
        precondition(!root.isPending, "double patch of pending MountRoot in _ConditionalNode")

        let patched = root.withMountedNode(as: Node.self) { node in
            updateNode(&node, &tx)
        }
        precondition(patched, "expected mounted conditional branch")
    }

    func collect(into ops: inout LayoutPass, context: inout _CommitContext) {
        if containerHandle == nil {
            containerHandle = ops.containerHandle
        }

        switch state {
        case .a(let a):
            a.collect(into: &ops, &context)
        case .b(let b):
            b.collect(into: &ops, &context)
        case .aWithBLeaving(let a, let b):
            a.collect(into: &ops, &context)

            let isRemovalCompleted = ops.withRemovalTracking { ops in
                b.collect(into: &ops, &context)
            }

            if isRemovalCompleted {
                b.unmount(&context)
                state = .a(a)
            }
        case .bWithALeaving(let b, let a):
            let isRemovalCompleted = ops.withRemovalTracking { ops in
                a.collect(into: &ops, &context)
            }

            b.collect(into: &ops, &context)

            if isRemovalCompleted {
                a.unmount(&context)
                state = .b(b)
            }
        }
    }

    public func unmount(_ context: inout _CommitContext) {
        switch state {
        case .a(let a):
            a.unmount(&context)
        case .b(let b):
            b.unmount(&context)
        case .aWithBLeaving(let a, let b), .bWithALeaving(let b, let a):
            a.unmount(&context)
            b.unmount(&context)
        }
    }
}
