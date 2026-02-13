import Reactivity

/// A property wrapper that tracks and controls focus for one or more views.
///
/// Use ``FocusState`` to:
/// - observe which view is currently focused, and
/// - move focus programmatically by assigning a new value.
/// - bind focusable views with ``View/focused(_:)`` or ``View/focused(_:equals:)``
///
/// This wrapper supports two common shapes:
/// - `Bool` for a single focused/not-focused target
/// - optional hashable values (for example an enum) to identify which view is focused
@propertyWrapper
public struct FocusState<Value: Hashable> {
    internal typealias Storage = FocusStateStorage<Value>

    private let noneValue: Value
    private var storage: Storage?

    /// Creates a boolean focus state.
    ///
    /// Use this when you only need to track whether one target is focused.
    /// Assign `true` to request focus, or `false` to clear focus.
    public init() where Value == Bool {
        self.noneValue = false
    }

    /// Creates an optional keyed focus state.
    ///
    /// Use this when a single optional value identifies the
    /// currently focused target. Assign a matching value to request focus,
    /// or `nil` to clear focus.
    public init<T: Hashable>() where Value == T? {
        self.noneValue = nil
    }

    /// The current focus value.
    ///
    /// Reading returns the currently focused value.
    /// Writing updates focus on the view with the matching value (if any).
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

    /// A binding projection used by `.focused(...)` modifiers.
    ///
    /// Access this value with the `$` prefix.
    /// Example: `input(...).focused($focusedField, equals: .username)`
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
    /// A projected focus binding type used by `.focused(...)`.
    ///
    /// Instances are created by ``FocusState/projectedValue`` (`$` syntax).
    struct Binding {
        internal let storage: Storage

        fileprivate init(storage: Storage) {
            self.storage = storage
        }
    }
}

internal final class FocusStateStorage<Value: Hashable> {
    private let registrar = ReactivityRegistrar()
    private let _valueID = PropertyID(0)

    private let noneValue: Value

    private var _value: Value

    private(set) var value: Value {
        get {
            registrar.access(_valueID)
            return _value
        }
        set {
            registrar.willSet(_valueID)
            _value = newValue
            registrar.didSet(_valueID)
        }
    }

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
        // NOTE: there should be no case where this is a problem, if another view
        // using this binding is focused it will happen "in transaction" (ie: before first read of the value)
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

        // clean up focus if this element was currently focused
        if value == self._value {
            self.value = noneValue
        }
    }
}

protocol Focusable: AnyObject {
    func focus()
    func blur()
}
