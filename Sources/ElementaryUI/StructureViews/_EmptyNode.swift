public struct _EmptyNode: _Reconcilable {
    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {}

    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {}

    public consuming func unmount(_ context: inout _CommitContext) {}
}
