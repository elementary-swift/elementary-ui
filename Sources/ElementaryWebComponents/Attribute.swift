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
        value.utf8.elementsEqual("true".utf8) ? true : value.utf8.elementsEqual("false".utf8) ? false : nil
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

protocol AnyAttributeBox: AnyObject {
    func trySetValue(_ text: String?) -> Bool
}

final class AttributeBox<Value: CustomElementAttributeValue>: AnyAttributeBox {
    private var registrar: ReactivityRegistrar?
    private var propertyID = PropertyID(0)

    private var _value: Value
    private let initialValue: Value

    init(_ initialValue: Value) {
        self._value = initialValue
        self.initialValue = initialValue
    }

    var value: Value {
        get {
            registrar?.access(propertyID)
            return _value
        }
        set {
            registrar?.willSet(propertyID)
            _value = newValue
            registrar?.didSet(propertyID)
        }
        _modify {
            registrar?.access(propertyID)
            registrar?.willSet(propertyID)
            yield &_value
            registrar?.didSet(propertyID)
        }
    }

    func attachReactivity(_ registrar: ReactivityRegistrar, id: PropertyID) {
        precondition(self.registrar == nil, "AttributeBox already attached to a registrar")
        self.registrar = registrar
        self.propertyID = id
    }

    func trySetValue(_ text: String?) -> Bool {
        let next: Value
        if let text {
            guard let decoded = Value.decodeAttribute(text) else { return false }
            next = decoded
        } else {
            next = initialValue
        }
        value = next
        return true
    }
}

/// A reactive, typed input supplied by an HTML attribute on a custom-element host.
///
/// The wrapper creates one slot. Reads and writes always go through that slot. Swift mutations
/// update the ElementaryUI view but intentionally do not reflect back to the host element's
/// HTML attribute.
@propertyWrapper
public struct Attribute<Value: CustomElementAttributeValue> {
    internal let box: AttributeBox<Value>

    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
        nonmutating _modify { yield &box.value }
    }

    public init(wrappedValue: Value) {
        box = AttributeBox(wrappedValue)
    }

    public init(wrappedValue: Value, _: String) {
        box = AttributeBox(wrappedValue)
    }

    public init() where Value: ExpressibleByNilLiteral {
        box = AttributeBox(Value(nilLiteral: ()))
    }

    public init(_ name: String) where Value: ExpressibleByNilLiteral {
        box = AttributeBox(Value(nilLiteral: ()))
    }
}
