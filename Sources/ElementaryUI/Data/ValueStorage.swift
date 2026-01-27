import Reactivity

public struct _StorageKey<Container, Value>: Sendable {
    private let defaultValueClosure: (@Sendable () -> sending Value)?
    internal let propertyID: PropertyID

    internal var defaultValue: Value {
        if let closure = defaultValueClosure {
            return closure()
        } else {
            print("ERROR: Unavailable default value accessed for \(Value.self) with property ID \(propertyID)")
            fatalError("Unavailable default value accessed")
        }
    }

    public init(_ propertyName: String, defaultValue: @autoclosure @Sendable @escaping () -> sending Value) {
        self.init(PropertyID(propertyName), defaultValue: defaultValue)
    }

    public init(_ propertyName: String) {
        self.init(PropertyID(propertyName), defaultValue: nil)
    }

    internal init(_ propertyID: PropertyID, defaultValue: (@Sendable () -> sending Value)? = nil) {
        self.propertyID = propertyID
        defaultValueClosure = defaultValue
    }
}
