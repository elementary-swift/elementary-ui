public struct _ConditionalNode {
    enum State {
        case a(MountRoot)
        case b(MountRoot)
        case aWithBLeaving(MountRoot, MountRoot)
        case bWithALeaving(MountRoot, MountRoot)
    }

    private var state: State
    private var context: _ViewContext

    init(aRoot: MountRoot? = nil, bRoot: MountRoot? = nil, context: borrowing _ViewContext) {
        switch (aRoot, bRoot) {
        case (let .some(a), nil):
            self.state = .a(a)
        case (nil, let .some(b)):
            self.state = .b(b)
        default:
            preconditionFailure("either aRoot or bRoot must be provided")
        }

        self.context = copy context
    }

    init(a: consuming AnyReconcilable? = nil, b: consuming AnyReconcilable? = nil, context: borrowing _ViewContext) {
        self.init(
            aRoot: a.map { MountRoot.mounted($0) },
            bRoot: b.map { MountRoot.mounted($0) },
            context: context
        )
    }

    init(a: consuming some _Reconcilable, context: borrowing _ViewContext) {
        self.init(a: AnyReconcilable(a), context: context)
    }

    init(b: consuming some _Reconcilable, context: borrowing _ViewContext) {
        self.init(b: AnyReconcilable(b), context: context)
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
                makeNode: makeNode,
                updateNode: updateNode
            )
            state = .a(a)
        case .b(let b):
            context.parentElement?.reportChangedChildren(.elementAdded, tx: &tx)
            let a = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            scheduleMaterialization([a], tx: &tx)

            b.apply(.startRemoval, &tx)
            context.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
            state = .aWithBLeaving(a, b)
        case .aWithBLeaving(let a, let b):
            patchActiveRoot(
                a,
                tx: &tx,
                makeNode: makeNode,
                updateNode: updateNode
            )
            state = .aWithBLeaving(a, b)
        case .bWithALeaving(let b, let a):
            patchActiveRoot(
                a,
                tx: &tx,
                makeNode: makeNode,
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
                makeNode: makeNode,
                updateNode: updateNode
            )
            state = .b(b)
        case .a(let a):
            context.parentElement?.reportChangedChildren(.elementAdded, tx: &tx)
            let b = makePendingRoot(transaction: tx.transaction, makeNode: makeNode)
            scheduleMaterialization([b], tx: &tx)

            a.apply(.startRemoval, &tx)
            context.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
            state = .bWithALeaving(b, a)
        case .aWithBLeaving(let a, let b):
            patchActiveRoot(
                b,
                tx: &tx,
                makeNode: makeNode,
                updateNode: updateNode
            )
            state = .bWithALeaving(b, a)
        case .bWithALeaving(let b, let a):
            patchActiveRoot(
                b,
                tx: &tx,
                makeNode: makeNode,
                updateNode: updateNode
            )
            state = .bWithALeaving(b, a)
        }
    }

    private mutating func makePendingRoot<Node: _Reconcilable>(
        transaction: Transaction,
        makeNode: @escaping (borrowing _ViewContext, inout _CommitContext) -> Node
    ) -> MountRoot {
        MountRoot.pending(
            seedContext: context,
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
        makeNode: @escaping (borrowing _ViewContext, inout _CommitContext) -> Node,
        updateNode: (inout Node, inout _TransactionContext) -> Void
    ) {
        if root.isPending {
            root.updatePendingCreate(
                seedContext: context,
                transaction: tx.transaction,
                create: { viewContext, ctx in
                    AnyReconcilable(makeNode(viewContext, &ctx))
                }
            )
            scheduleMaterialization([root], tx: &tx)
            return
        }

        let patched = root.withMountedNode(as: Node.self) { node in
            updateNode(&node, &tx)
        }
        precondition(patched, "expected mounted conditional branch")
    }

    private func scheduleMaterialization(_ roots: [MountRoot], tx: inout _TransactionContext) {
        guard !roots.isEmpty else { return }

        tx.scheduler.addCommitAction { ctx in
            for root in roots {
                root.materialize(&ctx)
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
