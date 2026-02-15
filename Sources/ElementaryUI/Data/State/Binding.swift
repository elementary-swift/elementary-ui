/// A property wrapper that creates a two-way connection to a value.
///
/// Use `Binding` to create a reference to a value that can be read and written.
/// Bindings are commonly used to pass mutable state to child views or to connect
/// UI controls to data.
///
/// ## Creating Bindings
///
/// You typically create bindings using one of these approaches:
///
/// 1. **From State**: Use the `$` prefix on a ``State`` property (in a ``View()-macro`` type):
/// ```swift
/// @State var text: String = ""
/// TextField(text: $text)  // $text is a Binding<String>
/// ```
///
/// 2. **Manual Creation**: Create a binding with custom get and set closures:
/// ```swift
/// let binding = Binding(
///     get: { model.value },
///     set: { model.value = $0 }
/// )
/// ```
///
/// 3. **Nested Properties**: Use ``Binding(_:)-macro`` for nested property access:
/// ```swift
/// @State var user: User = User()
/// TextField(text: #Binding(user.name))  // Access nested property
/// ```
@propertyWrapper
@dynamicMemberLookup
public struct Binding<V> {
    enum Storage {
        case stateAccessor(StateAccessor<V>)
        case getSet(() -> V, (V) -> Void)
    }

    let storage: Storage

    /// Creates a binding with explicit get and set closures.
    ///
    /// Use this initializer when you need to create a binding from custom logic:
    ///
    /// ```swift
    /// let binding = Binding(
    ///     get: { viewModel.count },
    ///     set: { viewModel.count = $0 }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - get: A closure that retrieves the current value.
    ///   - set: A closure that sets a new value.
    public init(get: @escaping () -> V, set: @escaping (V) -> Void) {
        storage = .getSet(get, set)
    }

    init(accessor: StateAccessor<V>) {
        storage = .stateAccessor(accessor)
    }

    /// The current value of the binding.
    ///
    /// Read this property to get the current value. Write to it to update the underlying value.
    public var wrappedValue: V {
        get {
            switch storage {
            case let .stateAccessor(accessor):
                return accessor.value
            case let .getSet(get, _):
                return get()
            }
        }
        nonmutating set {
            switch storage {
            case let .stateAccessor(accessor):
                accessor.value = newValue
            case let .getSet(_, set):
                #if hasFeature(Embedded) && compiler(<6.3)
                // FIXME: embedded - create issue and check with main
                if __omg_this_was_annoying_I_am_false {
                    _ = AnyValueBox.init(newValue)
                }
                #endif

                set(newValue)
            }
        }
    }

    /// Returns the binding itself.
    ///
    /// This allows you to use the `$` prefix on a binding to get the same binding back.
    public var projectedValue: Binding<V> {
        self
    }

    /// Creates a binding to a property of the wrapped value.
    ///
    /// Use this subscript to access nested properties of the bound value:
    ///
    /// ```swift
    /// @State var user = User(name: "Alice", email: "alice@example.com")
    /// let nameBinding = $user.name  // Binding<String>
    /// let emailBinding = $user.email  // Binding<String>
    /// ```
    ///
    /// - Parameter keypath: A writable key path to a property of the wrapped value.
    /// - Returns: A binding to the property at the key path.
    public subscript<P>(dynamicMember keypath: WritableKeyPath<V, P>) -> Binding<P> {
        Binding<P>(
            get: { self.wrappedValue[keyPath: keypath] },
            set: { self.wrappedValue[keyPath: keypath] = $0 }
        )
    }
}

extension Binding: Equatable {
    public static func == (lhs: Binding<V>, rhs: Binding<V>) -> Bool {
        switch (lhs.storage, rhs.storage) {
        case (.stateAccessor(let lhsAccessor), .stateAccessor(let rhsAccessor)):
            return lhsAccessor == rhsAccessor
        default:
            return false
        }
    }
}
