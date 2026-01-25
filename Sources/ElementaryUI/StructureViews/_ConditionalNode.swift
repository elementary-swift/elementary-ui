public final class _ConditionalNode {
    enum State {
        case a(AnyReconcilable)
        case b(AnyReconcilable)
        case aWithBLeaving(AnyReconcilable, AnyReconcilable)
        case bWithALeaving(AnyReconcilable, AnyReconcilable)
    }

    private var state: State
    private var context: _ViewContext

    init(a: consuming AnyReconcilable? = nil, b: consuming AnyReconcilable? = nil, context: borrowing _ViewContext) {
        switch (a, b) {
        case (let .some(a), nil):
            self.state = .a(a)
        case (nil, let .some(b)):
            self.state = .b(b)
        default:
            preconditionFailure("either a or b must be provided")
        }

        self.context = copy context
    }

    convenience init(a: consuming some _Reconcilable, context: borrowing _ViewContext) {
        self.init(a: AnyReconcilable(a), context: context)
    }

    convenience init(b: consuming some _Reconcilable, context: borrowing _ViewContext) {
        self.init(b: AnyReconcilable(b), context: context)
    }

    func patchWithA<NodeA: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: (borrowing _ViewContext, inout _TransactionContext) -> NodeA,
        updateNode: (NodeA, inout _TransactionContext) -> Void
    ) {
        switch state {
        case .a(let a):
            updateNode(a.unwrap(), &tx)
            state = .a(a)
        case .b(let b):
            let a = AnyReconcilable(makeNode(context, &tx))
            b.apply(.startRemoval, &tx)
            self.context.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
            state = .aWithBLeaving(a, b)
        case .aWithBLeaving(let a, let b):
            updateNode(a.unwrap(), &tx)
            state = .aWithBLeaving(a, b)
        case .bWithALeaving(let b, let a):
            updateNode(a.unwrap(), &tx)
            a.apply(.cancelRemoval, &tx)
            b.apply(.startRemoval, &tx)
            self.context.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
            state = .aWithBLeaving(a, b)
        }
    }

    func patchWithB<NodeB: _Reconcilable>(
        tx: inout _TransactionContext,
        makeNode: (borrowing _ViewContext, inout _TransactionContext) -> NodeB,
        updateNode: (NodeB, inout _TransactionContext) -> Void
    ) {
        switch state {
        case .b(let b):
            updateNode(b.unwrap(), &tx)
            state = .b(b)
        case .a(let a):
            let b = AnyReconcilable(makeNode(context, &tx))
            a.apply(.startRemoval, &tx)
            self.context.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
            state = .bWithALeaving(b, a)
        case .aWithBLeaving(let a, let b):
            updateNode(b.unwrap(), &tx)
            state = .bWithALeaving(b, a)
        case .bWithALeaving(let b, let a):
            updateNode(b.unwrap(), &tx)
            state = .bWithALeaving(b, a)
        }
    }

}

extension _ConditionalNode: _Reconcilable {
    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
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
            // NOTE: ordering of a before b is important because we don't want to track moves here
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

    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
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
