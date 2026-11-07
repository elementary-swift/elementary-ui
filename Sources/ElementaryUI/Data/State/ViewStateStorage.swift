import Reactivity

/// One value of a view's state.
public struct _ViewStateValue: ~Copyable {
    @usableFromInline var value: UniqueAny

    @inlinable
    init<V: ~Copyable>(_ value: consuming V) {
        self.value = UniqueAny(value)
    }
}

/// Tail-allocated values of one storage. All pointer handling stays in here.
@usableFromInline
final class _ViewStateBuffer: ManagedBuffer<_ViewStateBuffer.Header, _ViewStateValue> {
    @usableFromInline
    struct Header {
        @usableFromInline let registrar: ReactivityRegistrar
        @usableFromInline var count: Int

        @inlinable
        init() {
            registrar = ReactivityRegistrar()
            count = 0
        }
    }

    @inlinable
    static func create(
        count: Int,
        initializingWith initializer: (inout OutputSpan<_ViewStateValue>) -> Void
    ) -> _ViewStateBuffer {
        // Spelled out: through `Self`, Embedded IRGen on main snapshots asserts on the dynamic allocation.
        let buffer = unsafeDowncast(
            _ViewStateBuffer.create(minimumCapacity: count) { _ in Header() },
            to: _ViewStateBuffer.self
        )
        buffer.withUnsafeMutablePointers { header, elements in
            let slots = UnsafeMutableBufferPointer(start: elements, count: count)
            var span = OutputSpan(buffer: slots, initializedCount: 0)
            initializer(&span)
            header.pointee.count = span.finalize(for: slots)
            precondition(header.pointee.count == count, "State storage must be fully initialized")
        }
        return buffer
    }

    deinit {
        withUnsafeMutablePointers { header, values in
            _ = values.deinitialize(count: header.pointee.count)
        }
    }

    // ManagedBuffer never moves its header or elements, so the addresses outlive the closures.
    // Reading `header` directly copies the whole header.
    @inlinable
    var headerPointer: UnsafeMutablePointer<Header> {
        withUnsafeMutablePointerToHeader { $0 }
    }

    @inlinable
    func slot(_ index: Int) -> UnsafeMutablePointer<_ViewStateValue> {
        precondition(index >= 0 && index < headerPointer.pointee.count, "State index out of range")
        return withUnsafeMutablePointerToElements { $0 + index }
    }

    // Addressors, not `borrow`/`mutate`: see `UniqueAny.subscript(as:)`.
    @inlinable
    subscript(index: Int) -> _ViewStateValue {
        unsafeAddress { UnsafePointer(slot(index)) }
        unsafeMutableAddress { slot(index) }
    }
}

/// The reactive values of one view's state, or of one environment modifier.
public struct _ViewStateStorage {
    @usableFromInline let buffer: _ViewStateBuffer

    /// Creates a storage of exactly `count` values, appended in index order.
    @inlinable
    public init(count: Int, initializingWith initializer: (inout OutputSpan<_ViewStateValue>) -> Void) {
        buffer = .create(count: count, initializingWith: initializer)
    }

    /// A storage holding one value at index 0.
    init<V>(_ value: V) {
        self.init(count: 1) { $0.append(_ViewStateValue(value)) }
    }

    @inlinable
    var registrar: ReactivityRegistrar { buffer.headerPointer.pointee.registrar }

    /// Tracks reads, and notifies observers before and after each write.
    @inlinable
    public subscript<V: ~Copyable>(_ index: Int, as type: V.Type = V.self) -> V {
        _read {
            registrar.access(PropertyID(index))
            yield buffer[index].value[as: V.self]
        }
        nonmutating _modify {
            let registrar = registrar
            registrar.access(PropertyID(index))
            registrar.willSet(PropertyID(index))
            defer { registrar.didSet(PropertyID(index)) }
            yield &buffer[index].value[as: V.self]
        }
    }

    /// Direct access that neither tracks reads nor notifies observers.
    subscript<V: ~Copyable>(untracked index: Int, as type: V.Type = V.self) -> V {
        _read { yield buffer[index].value[as: V.self] }
        nonmutating _modify { yield &buffer[index].value[as: V.self] }
    }
}

/// Identifies one tracked value of a storage; access goes through `storage[index]`.
// No forwarding accessor here: each nested generic coroutine costs a heap-allocated frame.
@usableFromInline
struct StateAccessor<V: ~Copyable> {
    @usableFromInline let storage: _ViewStateStorage
    @usableFromInline let index: Int

    @inlinable
    init(storage: _ViewStateStorage, index: Int) {
        self.storage = storage
        self.index = index
    }
}

extension StateAccessor: Equatable {
    @usableFromInline
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage.buffer === rhs.storage.buffer && lhs.index == rhs.index
    }
}
