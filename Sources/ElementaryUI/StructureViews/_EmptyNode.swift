public struct _EmptyNode: _Reconcilable {
    public consuming func unmount(_ context: inout _CommitContext) {
    }
}
