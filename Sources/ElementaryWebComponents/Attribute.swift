/// A reactive, typed input supplied by an HTML attribute on a custom-element host.
///
/// The wrapper creates one slot. Reads and writes always go through that slot. Swift mutations
/// update the ElementaryUI view but intentionally do not reflect back to the host element's
/// HTML attribute.
@propertyWrapper
public struct Attribute<Value: ExpressibleByAttributeValue> {
    internal let box: AttributeValueBox<Value>

    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
        nonmutating _modify { yield &box.value }
    }

    public init(wrappedValue: Value) {
        box = AttributeValueBox(wrappedValue)
    }

    /// `name` is read by `@CustomElement` from the declaration. The runtime ignores it.
    public init(wrappedValue: Value, _ name: String) {
        _ = name
        box = AttributeValueBox(wrappedValue)
    }

    public init() where Value: ExpressibleByNilLiteral {
        box = AttributeValueBox(Value(nilLiteral: ()))
    }

    /// `name` is read by `@CustomElement` from the declaration. The runtime ignores it.
    public init(_ name: String) where Value: ExpressibleByNilLiteral {
        _ = name
        box = AttributeValueBox(Value(nilLiteral: ()))
    }
}
