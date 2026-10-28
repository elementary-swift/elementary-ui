import Synchronization

/// What trackers notify. Trackers hold it strongly: a ``ReactiveTracking/Listener`` unsubscribes
/// when dropped, a fired one-shot listener is removed lazily.
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
        let admittedState = state.withLock { state -> _ListenerState? in
            switch state {
            case .cancelled:
                return nil
            case .persistent:
                return .persistent
            case .oneShot:
                state = .cancelled
                return .oneShot
            }
        }
        guard let admittedState else { return false }
        onChange()
        return admittedState == .oneShot
    }
}

enum _ListenerState: Sendable {
    case persistent
    /// Cancelled before its handler runs, so writes made by the handler can't call it again.
    case oneShot
    case cancelled
}
