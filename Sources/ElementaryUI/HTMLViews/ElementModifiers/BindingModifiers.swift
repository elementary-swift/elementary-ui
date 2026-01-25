final class BindingModifier<Configuration>: DOMElementModifier, Unmountable where Configuration: BindingConfiguration {
    typealias Value = Binding<Configuration.Value>

    private var lastValue: Configuration.Value
    var binding: Value

    var mountedNode: DOM.Node?
    var sink: DOM.EventSink?
    var accessor: DOM.PropertyAccessor?
    var isDirty: Bool = false

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.lastValue = value.wrappedValue
        self.binding = value
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        self.binding = value

        if !Configuration.equals(binding.wrappedValue, lastValue) {
            self.lastValue = binding.wrappedValue
            markDirty(&context)
        }
    }

    private func markDirty(_ context: inout _TransactionContext) {
        precondition(mountedNode != nil, "Binding effect can only be marked dirty on a mounted element")
        guard !isDirty else { return }
        isDirty = true

        context.scheduler.addCommitAction(updateDOMNode)
    }

    private func updateDOMNode(_ context: inout _CommitContext) {
        guard let accessor = self.accessor else { return }
        guard let value = Configuration.writeValue(lastValue) else {
            logWarning("Cannot set value \(lastValue) to the DOM")
            return
        }

        logTrace("setting value \(value) to accessor")
        accessor.set(value)
        isDirty = false
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        if mountedNode != nil {
            assertionFailure("Binding effect can only be mounted on a single element")
            self.unmount(&context)
        }

        self.mountedNode = node
        self.accessor = context.dom.makePropertyAccessor(node, name: Configuration.propertyName)

        let sink = context.dom.makeEventSink { [self] name, event in
            guard let value = self.accessor?.get() else {
                logWarning("Unexpected property value read from accessor")
                return
            }

            guard let value = Configuration.readValue(value) else {
                logWarning("Unexpected property value read from accessor")
                return
            }

            self.lastValue = value
            self.binding.wrappedValue = value
        }

        context.dom.addEventListener(node, event: Configuration.eventName, sink: sink)

        // NOTE: we want to set the initial value - but we need to make sure that all
        // attributes are set before we do so - value properties in the DOM depend on attributes
        context.scheduler.addCommitAction(updateDOMNode)

        return AnyUnmountable(self)
    }

    func unmount(_ context: inout _CommitContext) {
        guard let sink = self.sink, let node = self.mountedNode else {
            // NOTE: since this object is used for both state and mounted effect, it will be unmounted twice
            return
        }

        context.dom.removeEventListener(node, event: "input", sink: sink)
        self.mountedNode = nil
        self.sink = nil
    }
}

protocol BindingConfiguration {
    associatedtype Value
    static var propertyName: String { get }
    static var eventName: String { get }
    static func readValue(_ jsValue: DOM.PropertyValue) -> Value?
    static func writeValue(_ value: Value) -> DOM.PropertyValue?
    static func equals(_ lhs: Value, _ rhs: Value) -> Bool
}

extension BindingConfiguration where Value == String {
    static func equals(_ lhs: Value, _ rhs: Value) -> Bool {
        lhs.utf8Equals(rhs)
    }
}

extension BindingConfiguration where Value: Equatable {
    static func equals(_ lhs: Value, _ rhs: Value) -> Bool {
        lhs == rhs
    }
}

extension BindingConfiguration where Value == Double {
    static func equals(_ lhs: Value, _ rhs: Value) -> Bool {
        // a bit hacky, but this is to avoid unnecessary updates when the value is NaN
        guard !(lhs.isNaN && rhs.isNaN) else { return true }
        return lhs == rhs
    }
}

struct TextBindingConfiguration: BindingConfiguration {
    typealias Value = String
    static var propertyName: String { "value" }
    static var eventName: String { "input" }
    static func readValue(_ jsValue: DOM.PropertyValue) -> Value? {
        switch jsValue {
        case let .string(value):
            return value
        default:
            return nil
        }
    }
    static func writeValue(_ value: Value) -> DOM.PropertyValue? {
        .string(value)
    }
}

struct NumberBindingConfiguration: BindingConfiguration {
    typealias Value = Double?
    static var propertyName: String { "valueAsNumber" }
    static var eventName: String { "input" }
    static func readValue(_ jsValue: DOM.PropertyValue) -> Value? {
        switch jsValue {
        case let .number(value):
            value.isNaN ? nil : value
        default:
            nil
        }
    }
    static func writeValue(_ value: Value) -> DOM.PropertyValue? {
        guard let value, !value.isNaN else {
            return .undefined
        }

        return .number(value)
    }
}

struct CheckboxBindingConfiguration: BindingConfiguration {
    typealias Value = Bool
    static var propertyName: String { "checked" }
    static var eventName: String { "change" }
    static func readValue(_ jsValue: DOM.PropertyValue) -> Value? {
        switch jsValue {
        case let .boolean(value):
            return value
        default:
            return nil
        }
    }
    static func writeValue(_ value: Value) -> DOM.PropertyValue? {
        .boolean(value)
    }
}
