public struct _StatefulNode<State, Child: _Reconcilable> {
    var state: State
    var child: Child
    private var onUnmount: ((inout _CommitContext) -> Void)?

    init(state: State, child: Child) {
        self.state = state
        self.child = child
    }

    private init(state: State, child: Child, onUnmount: ((inout _CommitContext) -> Void)? = nil) {
        self.state = state
        self.child = child
        self.onUnmount = onUnmount
    }

    init(state: State, child: Child) where State: Unmountable {
        self.init(state: state, child: child, onUnmount: state.unmount(_:))
    }
}

extension _StatefulNode: _Reconcilable {
    public consuming func unmount(_ context: inout _CommitContext) {
        child.unmount(&context)
        onUnmount?(&context)
    }
}
