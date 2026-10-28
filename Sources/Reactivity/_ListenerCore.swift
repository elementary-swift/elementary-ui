import Synchronization

/// What trackers notify. Trackers hold it strongly: a ``ReactiveTracking/Listener`` unsubscribes
/// when dropped, a fired one-shot listener is removed lazily.
final class _ListenerCore: Sendable {
    private let state: Mutex<_ListenerState>
    private let handler: _ListenerHandler

    init(_ state: _ListenerState = .persistent, handler: _ListenerHandler) {
        self.state = Mutex(state)
        self.handler = handler
    }

    var isCancelled: Bool { state.withLock { $0 == .cancelled } }

    // TODO: not safe for multi-threaded use. Cancelling doesn't wait for a handler call already
    // admitted on another thread, which can then run after this returns, with a released `context`.
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
        // TODO: may run after a concurrent `cancel()` returned (see `cancel()`).
        switch handler {
        case let .function(context, onChange):
            onChange(context)
        case let .closure(onChange):
            onChange()
        }
        return admittedState == .oneShot
    }
}

enum _ListenerState: Sendable {
    case persistent
    /// Cancelled before its handler runs, so writes made by the handler can't call it again.
    case oneShot
    case cancelled
}

// Unchecked: the owner of a `function` handler guarantees `context` may be used from any writer.
enum _ListenerHandler: @unchecked Sendable {
    /// Needs no closure context, so it costs no allocation.
    case function(context: UnsafeMutableRawPointer, onChange: @convention(c) (UnsafeMutableRawPointer) -> Void)
    case closure(@Sendable () -> Void)
}
