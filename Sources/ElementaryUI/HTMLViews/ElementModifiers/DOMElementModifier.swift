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
