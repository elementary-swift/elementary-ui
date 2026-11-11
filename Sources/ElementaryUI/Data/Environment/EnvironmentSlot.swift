/// The value one environment modifier provides, and the views that follow it.
final class EnvironmentSlot: DependencyNode {
    var value: UniqueAny

    init<V>(_ value: V) {
        self.value = UniqueAny(value)
        super.init()
    }
}

/// The node that reruns a view, for its `@Environment` properties to make it follow the
/// slots they loaded.
public struct _EnvironmentFollower {
    let node: DependencyNode

    // inline(never): one copy for all `Environment<V>` (code size)
    @inline(never)
    func follow(_ slot: EnvironmentSlot, ctx: inout _MountContext) {
        ctx.follow(slot, with: node)
    }
}
