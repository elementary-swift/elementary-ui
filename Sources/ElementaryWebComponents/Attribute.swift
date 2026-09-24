import Reactivity
import _UTF8Internals

/// A type that can be decoded from the textual value of an HTML attribute.
public protocol CustomElementAttributeValue {
    /// Decodes a present HTML attribute.
    ///
    /// Return `nil` when `value` is not a valid representation of `Self`.
    static func decodeAttribute(_ value: String) -> Self?
}

extension String: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> String? { value }
}

extension Bool: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Bool? {
        if value.utf8Equals("true") { return true }
        if value.utf8Equals("false") { return false }
        return nil
    }
}

extension Int: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Int? { Int(value) }
}

extension Int8: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Int8? { Int8(value) }
}

extension Int16: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Int16? { Int16(value) }
}

extension Int32: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Int32? { Int32(value) }
}

extension Int64: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Int64? { Int64(value) }
}

extension UInt: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> UInt? { UInt(value) }
}

extension UInt8: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> UInt8? { UInt8(value) }
}

extension UInt16: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> UInt16? { UInt16(value) }
}

extension UInt32: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> UInt32? { UInt32(value) }
}

extension UInt64: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> UInt64? { UInt64(value) }
}

extension Float: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Float? { Float(value) }
}

extension Double: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Double? { Double(value) }
}

extension Optional: CustomElementAttributeValue where Wrapped: CustomElementAttributeValue {
    public static func decodeAttribute(_ value: String) -> Self? {
        guard let decoded = Wrapped.decodeAttribute(value) else { return nil }
        return .some(.some(decoded))
    }
}

public extension CustomElementAttributeValue where Self: RawRepresentable, RawValue == String {
    static func decodeAttribute(_ value: String) -> Self? {
        Self(rawValue: value)
    }
}

/// One `@Attribute` value. The property wrapper creates it; attribute storage only indexes it.
public class AttributeSlot {
    var name: String = ""
    fileprivate var registrar: ReactivityRegistrar?
    fileprivate var propertyID = PropertyID(0)

    fileprivate init() {}

    func apply(_ value: String?) -> Bool { false }

    fileprivate func attach(_ registrar: ReactivityRegistrar, id: PropertyID) {
        self.registrar = registrar
        self.propertyID = id
    }
}

private final class StoredAttribute<Value: CustomElementAttributeValue>: AttributeSlot {
    private var stored: Value
    var declarationDefault: Value

    init(_ initialValue: Value) {
        stored = initialValue
        declarationDefault = initialValue
        super.init()
    }

    var value: Value {
        get {
            registrar?.access(propertyID)
            return stored
        }
        set {
            registrar?.willSet(propertyID)
            stored = newValue
            registrar?.didSet(propertyID)
        }
        _modify {
            registrar?.access(propertyID)
            registrar?.willSet(propertyID)
            yield &stored
            registrar?.didSet(propertyID)
        }
    }

    override func apply(_ text: String?) -> Bool {
        let next: Value
        if let text {
            guard let decoded = Value.decodeAttribute(text) else { return false }
            next = decoded
        } else {
            next = declarationDefault
        }
        value = next
        return true
    }
}

/// Indexed, reactive storage for a custom element's `@Attribute` properties.
///
/// The mounted element owns this storage. Each slot already exists on the view; this type
/// only decodes later host updates into those slots.
public final class _CustomElementAttributeStorage {
    private let slots: [AttributeSlot]
    private let registrar = ReactivityRegistrar()

    public init(_ slots: [AttributeSlot]) {
        self.slots = slots
        for index in slots.indices {
            slots[index].attach(registrar, id: PropertyID(index))
        }
    }

    /// Decodes `value` into the named slot, or restores the declaration default when `value` is `nil`.
    ///
    /// - Returns: `false` when `name` is unknown or `value` is present but cannot be decoded.
    ///   The slot is unchanged.
    public func apply(name: String, value: String?) -> Bool {
        guard let slot = slots.first(where: { $0.name.utf8Equals(name) }) else { return false }
        return slot.apply(value)
    }
}

/// A reactive, typed input supplied by an HTML attribute on a custom-element host.
///
/// The wrapper creates one slot. Reads and writes always go through that slot. Swift mutations
/// update the ElementaryUI view but intentionally do not reflect back to the host element's
/// HTML attribute.
@propertyWrapper
public struct Attribute<Value: CustomElementAttributeValue> {
    private let stored: StoredAttribute<Value>

    public var wrappedValue: Value {
        get { stored.value }
        nonmutating set { stored.value = newValue }
        nonmutating _modify { yield &stored.value }
    }

    public init(wrappedValue: Value) {
        stored = StoredAttribute(wrappedValue)
    }

    public init(wrappedValue: Value, _: String) {
        stored = StoredAttribute(wrappedValue)
    }

    public init() where Value: ExpressibleByNilLiteral {
        stored = StoredAttribute(Value(nilLiteral: ()))
    }

    public init(_: String) where Value: ExpressibleByNilLiteral {
        stored = StoredAttribute(Value(nilLiteral: ()))
    }

    /// Labels the slot this wrapper already created. Public so code generated by ``CustomElement()`` can call it.
    public func slot(named name: String, declarationDefault: Value) -> AttributeSlot {
        stored.name = name
        stored.declarationDefault = declarationDefault
        return stored
    }
}
