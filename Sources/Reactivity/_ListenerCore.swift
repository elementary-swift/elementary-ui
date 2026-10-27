import Synchronization

/// What trackers notify: a change callback that can be cancelled.
///
/// Trackers hold their listeners strongly. A ``ReactiveTracking/Listener`` unsubscribes when
/// it is dropped. A one-shot listener cancels itself when it fires and is dropped by trackers
/// lazily; it holds no dependencies, so a registrar that dies first releases it as well.
final class _ListenerCore: Sendable {
    private let state: Mutex<_ListenerState>
    private let onChange: @Sendable () -> Void

    init(_ state: _ListenerState = .persistent, onChange: @escaping @Sendable () -> Void) {
        self.state = Mutex(state)
        self.onChange = onChange
    }

    var isCancelled: Bool { state.withLock { $0 == .cancelled } }

    func cancel() { state.withLock { $0 = .cancelled } }

    /// Calls the handler unless cancelled. Returns whether a one-shot listener is now done.
    func notify() -> Bool {
        let admitted = state.withLock { state -> _ListenerState? in
            defer { if state == .oneShot { state = .cancelled } }
            return state == .cancelled ? nil : state
        }
        guard let admitted else { return false }
        onChange()
        return admitted == .oneShot
    }
}

enum _ListenerState: Sendable {
    case persistent
    /// Cancels itself on its first notification, before its handler runs, so writes made
    /// by the handler can't call it again.
    case oneShot
    case cancelled
}
