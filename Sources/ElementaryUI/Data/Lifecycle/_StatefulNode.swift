public struct _StatefulNode<State: ~Copyable, Child: _Reconcilable & ~Copyable>: ~Copyable, _Reconcilable {
    var state: State
    var child: Child
    private var onUnmount: ((inout _CommitContext) -> Void)?

    init(state: consuming State, child: consuming Child) {
        self.state = state
        self.child = child
    }

    private init(state: consuming State, child: consuming Child, onUnmount: ((inout _CommitContext) -> Void)? = nil) {
        self.state = state
        self.child = child
        self.onUnmount = onUnmount
    }

    init(state: consuming State, child: consuming Child) where State: Unmountable {
        self.init(state: state, child: child, onUnmount: state.unmount(_:))
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        child.unmount(&context)
        onUnmount?(&context)
    }
}
