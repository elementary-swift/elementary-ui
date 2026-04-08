public struct _EmptyNode: _Reconcilable & ~Copyable {
    public consuming func unmount(_ context: inout _CommitContext) {
    }
}
