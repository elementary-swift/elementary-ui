/// A property wrapper that reads and writes a value managed by the view system.
///
/// Use `@State` to store values that are owned and managed by a view. When the state
/// changes, the view automatically updates to reflect the new value.
///
/// - Important: `@State` only works in types marked with the ``View()-macro`` macro.
///   The macro sets up the infrastructure needed for state management.
///
/// ## Usage
///
/// ```swift
/// @View
/// struct Counter {
///     @State var count: Int = 0
///
///     var body: some View {
///         div {
///             p { "Count: \(count)" }
///             button { "Increment" }
///                 .onClick { count += 1 }
///         }
///     }
/// }
/// ```
///
/// ## Passing State to Child Views
///
/// Use the `$` prefix to pass a ``Binding`` to child views:
///
/// ```swift
/// @View
/// struct Parent {
///     @State var text: String = ""
///
///     var body: some View {
///         TextEditor(text: $text)
///     }
/// }
/// ```
@propertyWrapper
public struct State<V> {
    @usableFromInline let initialValue: V
    @usableFromInline var accessor: StateAccessor<V>?

    /// The current value of the state.
    ///
    /// Reading this property returns the current state value. Writing to it updates
    /// the state and triggers a view update.
    @inlinable
    public var wrappedValue: V {
        get {
            guard let accessor else { return initialValue }
            return accessor.storage[accessor.index]
        }
        nonmutating set {
            guard let accessor else { fatalError("State.set called outside of content") }
            accessor.storage[accessor.index] = newValue
        }
        nonmutating _modify {
            guard let accessor else { fatalError("State._modify called outside of content") }
            yield &accessor.storage[accessor.index]
        }
    }

    /// A binding to the state value.
    ///
    /// Access this property using the `$` prefix to create a ``Binding`` that can be
    /// passed to child views or used with two-way data binding.
    ///
    /// ```swift
    /// @State var text: String = ""
    /// let binding = $text  // Creates a Binding<String>
    /// ```
    public var projectedValue: Binding<V> {
        guard let accessor else { fatalError("State.projectedValue called outside of content") }
        return Binding(accessor: accessor)
    }

    /// Creates a state value with an initial value.
    ///
    /// - Parameter wrappedValue: The initial value for the state.
    public init(wrappedValue: V) {
        initialValue = wrappedValue
    }
}

public extension State {
    @inlinable
    mutating func __restoreState(storage: _ViewStateStorage, index: Int) {
        accessor = StateAccessor(storage: storage, index: index)
    }

    @inlinable
    func __initializeState(into values: inout OutputSpan<_ViewStateValue>) {
        values.append(_ViewStateValue(initialValue))
    }
}
