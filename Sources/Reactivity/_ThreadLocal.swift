#if _runtime(_multithreaded)
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#else
#error("Unsupported platform")
#endif

@usableFromInline
enum _ThreadLocal {
    @usableFromInline
    static let key: pthread_key_t = __makeKey()

    @inlinable
    static var value: UnsafeMutableRawPointer? {
        get { pthread_getspecific(key) }
        set { pthread_setspecific(key, newValue) }
    }

    static func __makeKey() -> pthread_key_t {
        var key: pthread_key_t = 0
        pthread_key_create(&key, nil)
        return key
    }
}
#else
// single-threaded runtime
@usableFromInline
enum _ThreadLocal {
    @usableFromInline
    nonisolated(unsafe) static var value: UnsafeMutableRawPointer?
}
#endif
