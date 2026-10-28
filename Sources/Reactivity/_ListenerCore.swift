import Synchronization

/// What trackers notify. Trackers hold it strongly: a ``ReactiveTracking/Listener`` releases it
/// when dropped, a fired one-shot listener is removed lazily.
@usableFromInline
final class _ListenerCore: Sendable {
    private let state: Atomic<_ListenerState>
    private let handler: _ListenerHandler

    init(_ state: _ListenerState = .persistent, handler: _ListenerHandler) {
        self.state = Atomic(state)
        self.handler = handler
    }

    var isCancelled: Bool { state.load(ordering: .acquiring) == .cancelled }

    // TODO: not safe for multi-threaded use. Cancelling doesn't wait for a handler call already
    // admitted on another thread, which can then run after this returns, with a released `context`.
    func cancel() { state.store(.cancelled, ordering: .releasing) }

    /// Calls the handler unless cancelled. Returns whether a one-shot listener is now done.
    func notify() -> Bool {
        switch state.load(ordering: .acquiring) {
        case .cancelled:
            return false
        case .persistent:
            callHandler()
            return false
        case .oneShot:
            // Of concurrent notifications, only the one that cancels it calls the handler.
            let (cancelled, _) = state.compareExchange(
                expected: .oneShot,
                desired: .cancelled,
                ordering: .acquiringAndReleasing
            )
            guard cancelled else { return false }
            callHandler()
            return true
        }
    }

    // TODO: may run after a concurrent `cancel()` returned (see `cancel()`).
    private func callHandler() {
        switch handler {
        case let .function(context, onChange):
            onChange(context)
        case let .closure(onChange):
            onChange()
        }
    }
}

enum _ListenerState: UInt8, AtomicRepresentable {
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
