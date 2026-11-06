/// The value one environment modifier provides to its subtree, and the views that read it.
///
/// Environment values only change while the modifier is patched, so readers are
/// invalidated explicitly in that transaction instead of being tracked reactively.
public final class _EnvironmentSlot {
    var value: UniqueAny
    var dependents = DependencyTracker()

    init<V>(_ value: consuming V) {
        self.value = UniqueAny(value)
    }
}
