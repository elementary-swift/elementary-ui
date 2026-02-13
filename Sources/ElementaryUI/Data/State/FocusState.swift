import Reactivity

@propertyWrapper
public struct FocusState<Value: Hashable> {
    internal typealias Storage = FocusStateStorage<Value>

    private let noneValue: Value
    private var storage: Storage?
    public init() where Value == Bool {
        self.noneValue = false
    }

    public init<T: Hashable>() where Value == T? {
        self.noneValue = nil
    }

    public var wrappedValue: Value {
        get {
            guard let storage else {
                logWarning("FocusState not initialized")
                return noneValue
            }
            return storage.value
        }
        nonmutating set {
            guard let storage else {
                logWarning("FocusState not initialized")
                return
            }
            storage.tryFocus(value: newValue)
        }
    }

    public var projectedValue: Binding {
        get {
            guard let storage else {
                assertionFailure("FocusState not initialized")
                logWarning("FocusState not initialized")
                return Binding(storage: Storage(noneValue: noneValue))
            }
            return Binding(storage: storage)
        }
    }
}

public extension FocusState {
    mutating func __restoreState(storage: _ViewStateStorage, index: Int) {
        self.storage = storage[index, as: Storage.self]
    }

    func __initializeState(storage: _ViewStateStorage, index: Int) {
        storage.initializeValueStorage(initialValue: Storage(noneValue: noneValue), index: index)
    }
}

public extension FocusState {
    struct Binding {
        internal let storage: Storage

        fileprivate init(storage: Storage) {
            self.storage = storage
        }
    }
}

internal final class FocusStateStorage<Value: Hashable> {
    private let registrar = ReactivityRegistrar()
    let noneValue: Value

    var _value: Value

    private(set) var value: Value {
        get {
            registrar.access(PropertyID(0))
            return _value
        }
        set {
            registrar.willSet(PropertyID(0))
            _value = newValue
            registrar.didSet(PropertyID(0))
        }
    }

    @ReactiveIgnored
    private var focusables: [Value: any Focusable] = [:]

    init(noneValue: Value) {
        self.noneValue = noneValue
        self._value = noneValue
    }

    func tryFocus(value: Value) {
        if value == noneValue {
            guard let currentFocusable = focusables[self._value] else {
                self.value = noneValue
                return
            }
            currentFocusable.blur()
        } else {
            guard let focusable = focusables[value] else {
                logWarning("No element found for focus value \(value)")
                return
            }

            focusable.focus()
        }
    }

    func reportFocus(value: Value) {
        // NOTE: this will cause a reactive update if anyone is observing the value
        self.value = value
    }

    func reportBlur(value: Value) {
        // NOTE: maybe add checks or something here? should be fine though, as changes are read after the "transaction" (ie: it will often be blur (old), focus (new), then read value)
        self.value = noneValue
    }

    func register(_ focusable: any Focusable, for value: Value) {
        assert(value != noneValue, "Cannot register focusable for none value")

        guard !focusables.keys.contains(value) else {
            logWarning("Multiple views registered for focus value \(value)")
            return
        }

        focusables[value] = focusable
    }

    func unregister(_ focusable: any Focusable, for value: Value) {
        guard let index = focusables.index(forKey: value) else { return }

        // NOTE: written like this to avoid an Embedded compiler crash (I guess it needs the type here)
        let currentFocusable: any Focusable = focusables.values[index]
        guard currentFocusable === focusable else { return }

        focusables.remove(at: index)
    }
}

protocol Focusable: AnyObject {
    func focus()
    func blur()
}
