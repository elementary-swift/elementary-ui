import Reactivity

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
        switch value.lowercased() {
        case "true": true
        case "false": false
        default: nil
        }
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

private final class AttributeStorage<Value> {
    private let propertyID = PropertyID(0)
    private let registrar = ReactivityRegistrar()

    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    var currentValue: Value {
        get {
            registrar.access(propertyID)
            return value
        }
        set {
            registrar.willSet(propertyID)
            value = newValue
            registrar.didSet(propertyID)
        }
        _modify {
            registrar.access(propertyID)
            registrar.willSet(propertyID)
            defer { registrar.didSet(propertyID) }
            yield &value
        }
    }
}

/// A reactive, typed input supplied by an HTML attribute on a custom-element host.
///
/// Swift mutations update the ElementaryUI view but intentionally do not reflect back to
/// the host element's HTML attribute.
@propertyWrapper
public struct Attribute<Value: CustomElementAttributeValue> {
    private let storage: AttributeStorage<Value>

    public var wrappedValue: Value {
        get { storage.currentValue }
        nonmutating set { storage.currentValue = newValue }
        nonmutating _modify { yield &storage.currentValue }
    }

    public init(wrappedValue: Value) {
        storage = AttributeStorage(wrappedValue)
    }

    public init(wrappedValue: Value, _: String) {
        storage = AttributeStorage(wrappedValue)
    }

    public init() where Value: ExpressibleByNilLiteral {
        storage = AttributeStorage(Value(nilLiteral: ()))
    }

    public init(_: String) where Value: ExpressibleByNilLiteral {
        storage = AttributeStorage(Value(nilLiteral: ()))
    }

    /// Applies an attribute value to this property wrapper.
    ///
    /// This is public so code generated in clients by ``CustomElement()`` can call it.
    /// Application code should normally mutate ``wrappedValue`` instead.
    public func _setAttributeValue(_ value: String) -> Bool {
        guard let decoded = Value.decodeAttribute(value) else { return false }
        storage.currentValue = decoded
        return true
    }
}
