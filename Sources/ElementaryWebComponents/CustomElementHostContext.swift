import Reactivity

public struct _CustomElementHostContext: ~Copyable {
    private var attributes: [PropertyID: any AttributeValueBoxing] = [:]
    private let registrar = ReactivityRegistrar()

    public mutating func linkAttribute(_ name: String, _ attribute: Attribute<some ExpressibleByAttributeValue>) {
        let id = PropertyID(name)
        assert(attributes[id] == nil, "Attribute already added")

        attribute.box.attachReactivity(registrar, id: id)
        attributes[id] = attribute.box
    }

    func trySetAttribute(_ name: String, value: String?) -> Bool {
        let id = PropertyID(name)
        guard let box = attributes[id] else { return false }
        return box.trySetValue(value)
    }
}

protocol AttributeValueBoxing: AnyObject {
    func trySetValue(_ text: String?) -> Bool
}

final class AttributeValueBox<Value: ExpressibleByAttributeValue>: AttributeValueBoxing {
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
            guard let decoded = Value(attributeValue: text) else { return false }
            next = decoded
        } else {
            next = initialValue
        }
        value = next
        return true
    }
}
