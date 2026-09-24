/// A type that can be created from the textual value of an HTML attribute.
public protocol ExpressibleByAttributeValue {
    /// Creates a value from a present HTML attribute.
    ///
    /// Returns `nil` when `attributeValue` is not a valid representation of `Self`.
    init?(attributeValue: String)
}

extension String: ExpressibleByAttributeValue {
    public init?(attributeValue: String) {
        self = attributeValue
    }
}

extension Bool: ExpressibleByAttributeValue {
    public init?(attributeValue: String) {
        if attributeValue.utf8.elementsEqual("true".utf8) {
            self = true
        } else if attributeValue.utf8.elementsEqual("false".utf8) {
            self = false
        } else {
            return nil
        }
    }
}

extension Int: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension Int8: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension Int16: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension Int32: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension Int64: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension UInt: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension UInt8: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension UInt16: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension UInt32: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension UInt64: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension Float: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension Double: ExpressibleByAttributeValue {
    public init?(attributeValue: String) { self.init(attributeValue) }
}

extension Optional: ExpressibleByAttributeValue where Wrapped: ExpressibleByAttributeValue {
    public init?(attributeValue: String) {
        guard let decoded = Wrapped(attributeValue: attributeValue) else { return nil }
        self = decoded
    }
}

public extension ExpressibleByAttributeValue where Self: RawRepresentable, RawValue == String {
    init?(attributeValue: String) {
        guard let value = Self(rawValue: attributeValue) else { return nil }
        self = value
    }
}
