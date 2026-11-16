#if _runtime(_multithreaded)
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported platform")
#endif

// The transaction is ambient context for the state changes made inside `withTransaction`.
// A change on one thread must not pick up another thread's animation, and transaction ids
// are only ever compared by schedulers on the thread that created them.
final class _TransactionScope {
    var current: Transaction?
    var lastId: UInt32 = 0

    private static let key: pthread_key_t = {
        var key = pthread_key_t()
        pthread_key_create(&key) { raw in
            let pointer: UnsafeMutableRawPointer? = raw
            if let pointer {
                Unmanaged<_TransactionScope>.fromOpaque(pointer).release()
            }
        }
        return key
    }()

    static var forCurrentThread: _TransactionScope {
        if let pointer = pthread_getspecific(key) {
            return Unmanaged<_TransactionScope>.fromOpaque(pointer).takeUnretainedValue()
        }
        let scope = _TransactionScope()
        pthread_setspecific(key, Unmanaged.passRetained(scope).toOpaque())
        return scope
    }
}

extension Transaction {
    internal static var _current: Transaction? {
        get { _TransactionScope.forCurrentThread.current }
        set { _TransactionScope.forCurrentThread.current = newValue }
    }

    internal static var lastId: UInt32 {
        get { _TransactionScope.forCurrentThread.lastId }
        set { _TransactionScope.forCurrentThread.lastId = newValue }
    }
}
#else
extension Transaction {
    internal static var _current: Transaction? = nil
    internal static var lastId: UInt32 = 0
}
#endif
