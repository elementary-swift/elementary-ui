public struct _ConditionalNode {
    enum State {
        case a(MountRoot)
        case b(MountRoot)
        case aWithBLeaving(MountRoot, MountRoot)
        case bWithALeaving(MountRoot, MountRoot)
    }

    private var state: State
    private var context: _ViewContext

    private init(state: State, context: borrowing _ViewContext) {
        self.state = state
        self.context = copy context
    }

    init<A: _Mountable>(
        a view: A,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) {
        let root = MountRoot(
            mountedFrom: context,
            transaction: context.mountRoot.inheritedTransaction(),
            ctx: &ctx,
            create: { context, ctx in
                AnyReconcilable(A._makeNode(view, context: context, ctx: &ctx))
            }
        )
        self.init(state: .a(root), context: context)
    }

    init<B: _Mountable>(
        b view: B,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) {
        let root = MountRoot(
            mountedFrom: context,
            transaction: context.mountRoot.inheritedTransaction(),
            ctx: &ctx,
            create: { context, ctx in
                AnyReconcilable(B._makeNode(view, context: context, ctx: &ctx))
            }
        )
        self.init(state: .b(root), context: context)
    }

    mutating func patchWithA<NodeA: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _CommitContext) -> NodeA,
        updateNode: (inout NodeA, inout _TransactionContext) -> Void
    ) {
        switch state {
        case .a(let a):
            patchActiveRoot(
                a,
                tx: &tx,
                updateNode: updateNode
            )
            state = .a(a)
        case .b(let b):
            context.parentElement?.reportChangedChildren(.elementAdded, tx: &tx)
            let a = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            schedulePendingMount([a], tx: &tx)

            b.apply(.startRemoval, &tx)
            context.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
            state = .aWithBLeaving(a, b)
        case .aWithBLeaving(let a, let b):
            patchActiveRoot(
                a,
                tx: &tx,
                updateNode: updateNode
            )
            state = .aWithBLeaving(a, b)
        case .bWithALeaving(let b, let a):
            patchActiveRoot(
                a,
                tx: &tx,
                updateNode: updateNode
            )
            a.apply(.cancelRemoval, &tx)
            b.apply(.startRemoval, &tx)
            context.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
            state = .aWithBLeaving(a, b)
        }
    }

    mutating func patchWithB<NodeB: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: @escaping (borrowing _ViewContext, inout _CommitContext) -> NodeB,
        updateNode: (inout NodeB, inout _TransactionContext) -> Void
    ) {
        switch state {
        case .b(let b):
            patchActiveRoot(
                b,
                tx: &tx,
                updateNode: updateNode
            )
            state = .b(b)
        case .a(let a):
            context.parentElement?.reportChangedChildren(.elementAdded, tx: &tx)
            let b = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            schedulePendingMount([b], tx: &tx)

            a.apply(.startRemoval, &tx)
            context.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
            state = .bWithALeaving(b, a)
        case .aWithBLeaving(let a, let b):
            patchActiveRoot(
                b,
                tx: &tx,
                updateNode: updateNode
            )
            state = .bWithALeaving(b, a)
        case .bWithALeaving(let b, let a):
            patchActiveRoot(
                b,
                tx: &tx,
                updateNode: updateNode
            )
            state = .bWithALeaving(b, a)
        }
    }

    private mutating func makePendingRoot<Node: _Reconcilable>(
        transaction: Transaction,
        makeNode: @escaping (borrowing _ViewContext, inout _CommitContext) -> Node
    ) -> MountRoot {
        MountRoot(
            pending: context,
            transaction: transaction,
            transitionPhase: .willAppear,
            create: { viewContext, ctx in
                AnyReconcilable(makeNode(viewContext, &ctx))
            }
        )
    }

    private mutating func patchActiveRoot<Node: _Reconcilable>(
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

    private func schedulePendingMount(_ roots: [MountRoot], tx: inout _TransactionContext) {
        guard !roots.isEmpty else { return }

        tx.scheduler.addCommitAction { ctx in
            for root in roots {
                root.mount(&ctx)
            }
        }
    }
}

extension _ConditionalNode: _Reconcilable {
    public mutating func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        switch state {
        case .a(let a):
            a.collectChildren(&ops, &context)
        case .b(let b):
            b.collectChildren(&ops, &context)
        case .aWithBLeaving(let a, let b):
            a.collectChildren(&ops, &context)

            let isRemovalCompleted = ops.withRemovalTracking { ops in
                b.collectChildren(&ops, &context)
            }

            if isRemovalCompleted {
                b.unmount(&context)
                state = .a(a)
            }
        case .bWithALeaving(let b, let a):
            let isRemovalCompleted = ops.withRemovalTracking { ops in
                a.collectChildren(&ops, &context)
            }

            b.collectChildren(&ops, &context)

            if isRemovalCompleted {
                a.unmount(&context)
                state = .b(b)
            }
        }
    }

    public mutating func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        switch state {
        case .a(let a):
            a.apply(op, &tx)
        case .b(let b):
            b.apply(op, &tx)
        case .aWithBLeaving(let a, let b), .bWithALeaving(let b, let a):
            a.apply(op, &tx)
            b.apply(op, &tx)
        }
    }

    public consuming func unmount(_ context: inout _CommitContext) {
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

extension _ContainerLayoutPass {
    mutating func withRemovalTracking(_ block: (inout Self) -> Void) -> Bool {
        let index = entries.count
        block(&self)
        var isRemoved = true
        for entry in entries[index..<entries.count] {
            if entry.kind != .removed {
                isRemoved = false
                break
            }
        }
        return isRemoved
    }
}
