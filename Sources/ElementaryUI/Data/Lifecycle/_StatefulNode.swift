public struct _StatefulNode<State: ~Copyable, Child: ~Copyable>: ~Copyable {
    var state: State
    var child: Child

    init(state: consuming State, child: consuming Child) {
        self.state = state
        self.child = child
    }

    /// Registers `state` for unmounting; call after mounting `child`.
    init(registering state: consuming State, child: consuming Child, ctx: inout _MountContext) where State: Unmountable {
        ctx.registerUnmount(state)
        self.state = state
        self.child = child
    }
}
