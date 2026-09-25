/// A property that updates the view when its host's HTML attribute changes.
///
/// `@CustomElement` derives the HTML attribute name by converting the Swift property name
/// to lowercase kebab case: `stepSize` becomes `step-size`, `URLValue` becomes `url-value`,
/// and `user_id` becomes `user-id`. Pass an explicit name, such as
/// `@Attribute("custom-name")`, to override this conversion.
///
/// Values are decoded using ``ExpressibleByAttributeValue``. Removing the attribute restores
/// the initial value; invalid values leave the current value unchanged and log a warning.
/// Assigning to this property updates the view without changing the host's HTML attribute.
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

    /// Uses the specified HTML attribute name.
    /// `@CustomElement` requires a string literal containing a valid lowercase HTML attribute name.
    public init(wrappedValue: Value, _ name: String) {
        _ = name
        box = AttributeValueBox(wrappedValue)
    }

    public init() where Value: ExpressibleByNilLiteral {
        box = AttributeValueBox(Value(nilLiteral: ()))
    }

    /// Uses the specified HTML attribute name.
    /// `@CustomElement` requires a string literal containing a valid lowercase HTML attribute name.
    public init(_ name: String) where Value: ExpressibleByNilLiteral {
        _ = name
        box = AttributeValueBox(Value(nilLiteral: ()))
    }
}
