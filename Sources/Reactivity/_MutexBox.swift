#if _runtime(_multithreaded)
import Synchronization
final class MutexBox<State: ~Copyable>: Sendable {
    private let state: Mutex<State>

    init(_ state: consuming sending State) {
        self.state = Mutex(state)
    }

    func withLock<Result>(_ body: sending (inout sending State) -> sending Result) -> sending Result {
        state.withLock(body)
    }

    var id: ObjectIdentifier { ObjectIdentifier(self) }
}
#else
final class MutexBox<State: ~Copyable>: @unchecked Sendable {
    private var state: State

    init(_ state: consuming sending State) {
        self.state = state
    }

    func withLock<Result>(_ body: (inout sending State) -> sending Result) -> sending Result {
        body(&state)
    }

    var id: ObjectIdentifier { ObjectIdentifier(self) }
}
#endif
