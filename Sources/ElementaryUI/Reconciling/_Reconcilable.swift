// TODO: either get rid of this procol entirely, or at least move the apply/collectChildren stuff somewhere out of this
public protocol _Reconcilable {
    mutating func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext)

    mutating func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext)

    // TODO: should this be destroy?
    consuming func unmount(_ context: inout _CommitContext)
}

public enum _ReconcileOp {
    case startRemoval
    case cancelRemoval
    case markAsMoved
    case markAsLeaving
}

struct AnyReconcilable {
    class _Box {
        func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {}
        func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {}
        func unmount(_ context: inout _CommitContext) {}
    }

    final class _TypedBox<R: _Reconcilable>: _Box {
        var node: R

        init(_ node: consuming R) { self.node = node }

        override func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
            node.apply(op, &tx)
        }

        override func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
            node.collectChildren(&ops, &context)
        }

        override func unmount(_ context: inout _CommitContext) {
            node.unmount(&context)
        }
    }

    private var box: _Box

    init<R: _Reconcilable>(_ node: R) {
        self.box = _TypedBox(node)

    }

    // TODO: get rid of all these functions and use environment hooks to participate in whatever each node actually needs
    func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        box.apply(op, &tx)
    }

    func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        box.collectChildren(&ops, &context)
    }

    func unmount(_ context: inout _CommitContext) {
        box.unmount(&context)
    }

    func modify<R: _Reconcilable>(as type: R.Type = R.self, _ body: (inout R) -> Void) {
        let box = unsafeDowncast(self.box, to: _TypedBox<R>.self)
        body(&box.node)
    }
}
