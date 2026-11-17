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

@usableFromInline
package struct ThreadLocalSlot: Sendable {
    @usableFromInline
    let key: pthread_key_t

    package init() {
        var key = pthread_key_t()
        pthread_key_create(&key, nil)
        self.key = key
    }

    @inlinable
    package var value: UnsafeMutableRawPointer? {
        get { pthread_getspecific(key) }
        nonmutating set { pthread_setspecific(key, newValue) }
    }
}
#else
@usableFromInline
package struct ThreadLocalSlot: @unchecked Sendable {
    @usableFromInline
    let storage: UnsafeMutablePointer<UnsafeMutableRawPointer?>

    package init() {
        storage = .allocate(capacity: 1)
        storage.initialize(to: nil)
    }

    @inlinable
    package var value: UnsafeMutableRawPointer? {
        get { storage.pointee }
        nonmutating set { storage.pointee = newValue }
    }
}
#endif
