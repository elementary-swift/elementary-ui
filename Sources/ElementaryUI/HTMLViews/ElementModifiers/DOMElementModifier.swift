protocol DOMElementModifier: AnyObject {
    associatedtype Value

    static var key: DOMElementModifiers.Key<Self> { get }

    init(value: consuming Value, upstream: borrowing DOMElementModifiers)
    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext)

    /// Mounts on `node`, registering any unmount work on `context`.
    func mount(_ node: DOM.Node, _ context: inout _MountContext)

    /// The attributes this modifier adds to its element when rendered on the server.
    /// TODO: this will ideally be replaced once we have an upstream Elementary element modifier API.
    static func serverAttributes(for value: Value) -> _AttributeStorage
}

extension DOMElementModifier {
    static func serverAttributes(for value: Value) -> _AttributeStorage { .none }
}

extension DOMElementModifier {
    static var key: DOMElementModifiers.Key<Self> {
        DOMElementModifiers.Key(Self.self)
    }
}

struct DOMElementModifiers {
    struct Key<Directive: DOMElementModifier> {
        let typeID: ObjectIdentifier

        init(_: Directive.Type) {
            typeID = ObjectIdentifier(Directive.self)
        }
    }

    // Using arrays for stable ordering.
    // Modifier counts are typically small (0-5), so linear search probably outperforms hashing anyway.
    private var keys: [ObjectIdentifier] = []
    private var values: [any DOMElementModifier] = []

    var isEmpty: Bool {
        keys.isEmpty
    }

    subscript<Directive: DOMElementModifier>(_ key: Key<Directive>) -> Directive? {
        get {
            guard let i = keys.firstIndex(of: key.typeID) else { return nil }
            // The key identifies the type, so no dynamic cast is needed.
            return unsafeDowncast(values[i], to: Directive.self)
        }
        set {
            if let i = keys.firstIndex(of: key.typeID) {
                if let newValue = newValue {
                    values[i] = newValue
                } else {
                    keys.remove(at: i)
                    values.remove(at: i)
                }
            } else if let newValue = newValue {
                keys.append(key.typeID)
                values.append(newValue)
            }
        }
    }

    mutating func take() -> [any DOMElementModifier] {
        let result = values
        keys.removeAll(keepingCapacity: true)
        values.removeAll(keepingCapacity: true)
        return result
    }
}

protocol Invalidateable: AnyObject {
    func invalidate(_ context: inout _TransactionContext)
}

/// The dependents to invalidate when a value changes, in registration order.
///
/// Dependents are held strongly until removed, which also breaks the cycles
/// they usually form with their source. Removal leaves a tombstone, so
/// removing dependents in registration order (the order slots unmount in)
/// stays O(1); the storage is compacted once half of it is tombstones.
struct DependencyTracker: ~Copyable {
    // A closure per dependent rather than `any Invalidateable`: an existential
    // needs a witness table per generic conformer, which is large in Embedded.
    private struct Dependent {
        /// `nil` once removed.
        var id: ObjectIdentifier?
        var invalidate: (inout _TransactionContext) -> Void
    }

    private var dependents: [Dependent] = []
    private var firstLive = 0
    private var removedCount = 0

    var isEmpty: Bool {
        dependents.count == removedCount
    }

    mutating func addDependency(_ dependent: some Invalidateable) {
        dependents.append(Dependent(id: ObjectIdentifier(dependent), invalidate: dependent.invalidate(_:)))
    }

    mutating func removeDependency(_ dependent: some Invalidateable) {
        remove(ObjectIdentifier(dependent))
    }

    // Not generic, so it isn't specialized for every kind of dependent (code size).
    private mutating func remove(_ id: ObjectIdentifier) {
        var index = firstLive
        while index < dependents.count, dependents[index].id != id {
            index &+= 1
        }
        guard index < dependents.count else { return }

        dependents[index] = Dependent(id: nil, invalidate: { _ in })
        removedCount &+= 1

        if removedCount * 2 > dependents.count {
            dependents.removeAll { $0.id == nil }
            firstLive = 0
            removedCount = 0
        } else if index == firstLive {
            while dependents[firstLive].id == nil { firstLive &+= 1 }
        }
    }

    borrowing func invalidateAll(_ context: inout _TransactionContext) {
        // Tombstones invalidate nothing. Iterating holds the storage, so
        // dependents may register or remove others meanwhile.
        for dependent in dependents {
            dependent.invalidate(&context)
        }
    }
}
