import Reactivity

/// Tail-allocated values of one storage. All pointer handling stays in here.
final class _ViewStateBuffer: ManagedBuffer<_ViewStateBuffer.Header, UniqueAny> {
    struct Header {
        let registrar = ReactivityRegistrar()
        // `ManagedBuffer.capacity` asks the allocator on every read.
        let capacity: Int
        var count = 0
    }

    static func create(capacity: Int) -> _ViewStateBuffer {
        unsafeDowncast(create(minimumCapacity: capacity) { _ in Header(capacity: capacity) }, to: _ViewStateBuffer.self)
    }

    deinit {
        withUnsafeMutablePointers { header, values in
            _ = values.deinitialize(count: header.pointee.count)
        }
    }

    // ManagedBuffer never moves its header or elements, so the addresses outlive the closures.
    // Reading `header` directly copies the whole header.
    private var headerPointer: UnsafeMutablePointer<Header> {
        withUnsafeMutablePointerToHeader { $0 }
    }

    private var elementsPointer: UnsafeMutablePointer<UniqueAny> {
        withUnsafeMutablePointerToElements { $0 }
    }

    var registrar: ReactivityRegistrar { headerPointer.pointee.registrar }

    func append(_ value: consuming UniqueAny, at index: Int) {
        let header = headerPointer
        precondition(index == header.pointee.count, "State storage must be initialized in order")
        precondition(index < header.pointee.capacity, "State storage capacity exceeded")
        (elementsPointer + index).initialize(to: value)
        header.pointee.count = index &+ 1
    }

    private func slot(_ index: Int) -> UnsafeMutablePointer<UniqueAny> {
        precondition(index >= 0 && index < headerPointer.pointee.count, "State index out of range")
        return elementsPointer + index
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
        buffer.append(UniqueAny(initialValue), at: index)
    }

    var registrar: ReactivityRegistrar { buffer.registrar }

    /// Tracks reads, and notifies observers before and after each write.
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
