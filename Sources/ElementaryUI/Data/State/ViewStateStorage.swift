import Reactivity

/// Tail-allocated values of one storage. All pointer handling stays in here.
final class _ViewStateBuffer: ManagedBuffer<_ViewStateBuffer.Header, UniqueAny> {
    struct Header {
        let registrar = ReactivityRegistrar()
        var count = 0
    }

    static func create(capacity: Int) -> _ViewStateBuffer {
        unsafeDowncast(create(minimumCapacity: capacity) { _ in Header() }, to: _ViewStateBuffer.self)
    }

    deinit {
        withUnsafeMutablePointers { header, values in
            _ = values.deinitialize(count: header.pointee.count)
        }
    }

    func append(_ value: consuming UniqueAny) {
        precondition(header.count < capacity, "State storage capacity exceeded")
        let count = header.count
        withUnsafeMutablePointerToElements { $0 + count }.initialize(to: value)
        header.count = count + 1
    }

    // ManagedBuffer never moves its elements, so the address outlives the closure.
    private func slot(_ index: Int) -> UnsafeMutablePointer<UniqueAny> {
        precondition(index >= 0 && index < header.count, "State index out of range")
        return withUnsafeMutablePointerToElements { $0 + index }
    }

    // Addressors, not `borrow`/`mutate`: see `UniqueAny.subscript(as:)`.
    subscript(index: Int) -> UniqueAny {
        unsafeAddress { UnsafePointer(slot(index)) }
        unsafeMutableAddress { slot(index) }
    }
}

/// The reactive values of one view's state, or of one environment modifier.
public struct _ViewStateStorage {
    let buffer: _ViewStateBuffer

    public init(capacity: Int) {
        buffer = .create(capacity: capacity)
    }

    /// A storage holding one value at index 0.
    init<V: ~Copyable>(_ value: consuming V) {
        self.init(capacity: 1)
        initializeValueStorage(initialValue: value, index: 0)
    }

    public func initializeValueStorage<V: ~Copyable>(initialValue: consuming V, index: Int) {
        precondition(index == buffer.header.count, "State storage must be initialized in order")
        buffer.append(UniqueAny(initialValue))
    }

    var registrar: ReactivityRegistrar { buffer.header.registrar }

    /// Tracks reads, and notifies observers before and after each write.
    ///
    /// All side effects live here; the layers below are pure addressors.
    public subscript<V: ~Copyable>(_ index: Int, as type: V.Type = V.self) -> V {
        _read {
            registrar.access(PropertyID(index))
            yield buffer[index][as: V.self]
        }
        nonmutating _modify {
            let registrar = registrar
            registrar.access(PropertyID(index))
            registrar.willSet(PropertyID(index))
            defer { registrar.didSet(PropertyID(index)) }
            yield &buffer[index][as: V.self]
        }
    }

    /// Direct access that neither tracks reads nor notifies observers.
    subscript<V: ~Copyable>(untracked index: Int, as type: V.Type = V.self) -> V {
        _read { yield buffer[index][as: V.self] }
        nonmutating _modify { yield &buffer[index][as: V.self] }
    }
}

/// Identifies one tracked value of a storage; access goes through `storage[index]`.
// No forwarding accessor here: each nested generic coroutine costs a heap-allocated frame.
struct StateAccessor<V: ~Copyable> {
    let storage: _ViewStateStorage
    let index: Int
}

extension StateAccessor: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage.buffer === rhs.storage.buffer && lhs.index == rhs.index
    }
}
