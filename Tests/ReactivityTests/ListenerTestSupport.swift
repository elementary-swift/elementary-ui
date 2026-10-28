@testable import Reactivity

extension ReactiveTracking.Listener {
    /// A listener that observes nothing until it tracks.
    init(onChange: @escaping @Sendable () -> Void) {
        self.init(tracking: ReactiveTracking.AccessedDependencies(), onChange: onChange)
    }
}
