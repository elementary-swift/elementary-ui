import Builtin

// Holds either T directly or an UnsafeMutablePointer<T> to a heap slot, as selected by _UniqueAnyLayout.
// This buffer owns no cleanup; the matching witness handles its hidden value.
@_rawLayout(likeArrayOf: _TextNode, count: 1)
private struct _UniqueAnyStorage: ~Copyable {
    // Stored must fit and be bitwise-takable.
    @inline(__always)
    init<Stored: ~Copyable>(storing value: consuming Stored) {
        address.bindMemory(to: Stored.self, capacity: 1).initialize(to: value)
    }

    // Valid only while self is not moved; callers must not escape it.
    @inline(__always)
    var address: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(Builtin.addressOfRawLayout(self))
    }
}

@inline(__always)
private func _fitsInline<T: ~Copyable>(_: T.Type) -> Bool {
    MemoryLayout<T>.size <= MemoryLayout<_UniqueAnyStorage>.size
        && MemoryLayout<T>.alignment <= MemoryLayout<_UniqueAnyStorage>.alignment
        && Bool(Builtin.isbitwisetakable(T.self))
}

// Used through metatypes only: no instances or stored closure contexts.
private class _UniqueAnyWitness {
    class func destroy(_ storage: UnsafeMutableRawPointer) { fatalError("abstract") }
}

private final class _InlineWitness<T: ~Copyable>: _UniqueAnyWitness {
    override class func destroy(_ storage: UnsafeMutableRawPointer) {
        storage.assumingMemoryBound(to: T.self).deinitialize(count: 1)
    }
}

private final class _HeapWitness<T: ~Copyable>: _UniqueAnyWitness {
    override class func destroy(_ storage: UnsafeMutableRawPointer) {
        let pointer = storage.assumingMemoryBound(to: UnsafeMutablePointer<T>.self).pointee
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }
}

// Raw bytes relocate without a typed move, so only bitwise-takable values may
// live directly in the buffer. Other values stay at a stable heap address.
private struct _UniqueAnyLayout: ~Copyable {
    var storage: _UniqueAnyStorage
    let witness: _UniqueAnyWitness.Type

    @inline(__always)
    init<T: ~Copyable>(_ value: consuming T) {
        if _fitsInline(T.self) {
            storage = _UniqueAnyStorage(storing: value)
            witness = _InlineWitness<T>.self
        } else {
            let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
            pointer.initialize(to: value)
            storage = _UniqueAnyStorage(storing: pointer)
            witness = _HeapWitness<T>.self
        }
    }
}

/// A uniquely owned value of any type, including noncopyable ones.
///
/// Small bitwise-takable values are stored inline; others live in a single heap slot.
/// Access goes through `self[as: T.self]`, which borrows or mutates in place.
// Embedded Swift requires this raw-layout owner to have a frozen layout.
@usableFromInline
@frozen
@_rawLayout(like: _UniqueAnyLayout)
struct UniqueAny: ~Copyable {
    @inline(__always)
    init<T: ~Copyable>(_ value: consuming T) {
        _layout.initialize(to: _UniqueAnyLayout(value))
    }

    deinit {
        _layout.pointee.witness.destroy(_layout.pointee.storage.address)
    }

    @inline(__always)
    private var _layout: UnsafeMutablePointer<_UniqueAnyLayout> {
        UnsafeMutableRawPointer(Builtin.addressOfRawLayout(self))
            .assumingMemoryBound(to: _UniqueAnyLayout.self)
    }

    // Precondition: T is exactly the type passed to init.
    @inline(__always)
    private func _address<T: ~Copyable>(of _: T.Type) -> UnsafeMutablePointer<T> {
        let witness = _layout.pointee.witness
        let storage = _layout.pointee.storage.address
        if _fitsInline(T.self) {
            precondition(witness == _InlineWitness<T>.self, "Incorrect erased value type")
            return storage.assumingMemoryBound(to: T.self)
        } else {
            precondition(witness == _HeapWitness<T>.self, "Incorrect erased value type")
            return storage.assumingMemoryBound(to: UnsafeMutablePointer<T>.self).pointee
        }
    }

    /// The stored value, which must be exactly of type `T`.
    ///
    /// Pure addressors: no side effects, so they compose under `_read`/`_modify`.
    // Keep these as addressors, not `borrow`/`mutate`: on Swift 6.4, a `_modify` that
    // yields through a `mutate` accessor miscompiles, and assigning a reference value
    // double-frees it. `_ViewStateStorage`'s tracked subscript is such a `_modify`.
    @inline(__always)
    subscript<T: ~Copyable>(as type: T.Type = T.self) -> T {
        unsafeAddress { UnsafePointer(_address(of: T.self)) }
        unsafeMutableAddress { _address(of: T.self) }
    }
}
