import Reactivity

/// A property wrapper that reads a value from the view's environment.
///
/// Use `@Environment` to read values that are passed down through the view hierarchy.
/// Environment values are shared by all descendant views and can be overridden at any level.
///
/// - Important: `@Environment` only works in types marked with the ``View()`` macro.
///   The macro sets up the infrastructure needed for environment access.
///
/// ## Usage
///
/// Define custom environment values using the `@Entry` macro:
///
/// ```swift
/// extension EnvironmentValues {
///     @Entry var theme: Theme = .light
/// }
/// ```
///
/// Read environment values in your views:
///
/// ```swift
/// @View
/// struct ThemedView {
///     @Environment(#Key(\.theme)) var theme
///
///     var body: some View {
///         div { "Current theme: \(theme.name)" }
///             .style("color", theme.textColor)
///     }
/// }
/// ```
///
/// Set environment values for descendant views:
///
/// ```swift
/// ThemedView()
///     .environment(#Key(\.theme), .dark)
/// ```
///
/// - Note: Environment values are read-only from the view's perspective. To modify them,
///   pass a new value using ``View/environment(_:_:)``.
@propertyWrapper
public struct Environment<V> {
    enum Storage {
        case value(V)
        case slot(_EnvironmentSlot)
        case valueKey(EnvironmentValues._Key<V>)
        case objectReader(ObjectStorageReader<V>, _EnvironmentSlot?)
    }

    var storage: Storage

    /// Creates an environment property for the given key.
    ///
    /// - Parameter accessor: A key that identifies the environment value to read.
    public init(_ accessor: EnvironmentValues._Key<V>) {
        storage = .valueKey(accessor)
    }

    init(_ objectReader: ObjectStorageReader<V>) {
        storage = .objectReader(objectReader, nil)
    }

    /// The current value from the environment.
    ///
    /// Read this property to access the environment value. The value is resolved from
    /// the view hierarchy at render time.
    public var wrappedValue: V {
        switch storage {
        case let .value(value):
            value
        case let .slot(slot):
            slot.value[as: V.self]
        case let .valueKey(accessor):
            accessor.defaultValue
        case let .objectReader(reader, slot):
            reader.read(slot)
        }
    }

    public mutating func __load(from context: borrowing _ViewContext) {
        __load(from: context.environment)
    }

    mutating func __load(from values: borrowing EnvironmentValues) {
        switch storage {
        case let .valueKey(key):
            if let slot = values.entries[key.propertyID] {
                storage = .slot(slot)
            } else {
                storage = .value(key.defaultValue)
            }
        case let .objectReader(reader, _):
            storage = .objectReader(reader, values.entries[reader.propertyID])
        default:
            fatalError("Cannot load environment value twice")
        }
    }

    /// Calls `visit` with the slot this property was loaded from, if any.
    public func __visitSlot(_ visit: (_EnvironmentSlot) -> Void) {
        switch storage {
        case let .slot(slot):
            visit(slot)
        case let .objectReader(_, slot?):
            visit(slot)
        default:
            break
        }
    }
}

/// A collection of environment values that are propagated through the view hierarchy.
///
/// `EnvironmentValues` is the storage container for all environment values. You extend
/// this type to add custom environment values using the `@Entry` macro.
///
/// ## Defining Custom Environment Values
///
/// ```swift
/// extension EnvironmentValues {
///     @Entry var apiClient: APIClient = APIClient()
///     @Entry var theme: Theme = .light
///     @Entry var userId: String? = nil
/// }
/// ```
///
/// ## Reading Environment Values
///
/// Use the `@Environment` property wrapper in your views:
///
/// ```swift
/// @View
/// struct UserProfile {
///     @Environment(#Key(\.apiClient)) var apiClient
///     @Environment(#Key(\.userId)) var userId
///
///     var body: some View {
///         // Use environment values
///     }
/// }
/// ```
///
/// ## Setting Environment Values
///
/// Use the ``View/environment(_:_:)`` modifier to set values for descendant views:
///
/// ```swift
/// UserProfile()
///     .environment(#Key(\.userId), "123")
///     .environment(#Key(\.theme), .dark)
/// ```
public struct EnvironmentValues {
    /// A type-erased key for accessing environment values.
    ///
    /// Do not create instances of this type manually. Use the ``#Key`` macro to create keys.
    public typealias _Key<Value> = _StorageKey<Self, Value>

    /// The slot of the innermost modifier setting each key.
    var entries: [PropertyID: _EnvironmentSlot] = [:]

    package init() {}

    /// Accesses an environment value using a key.
    ///
    /// - Parameter key: A key identifying the environment value.
    /// - Returns: The value for the key, or the key's default value if not set.
    public subscript<Value>(key: _Key<Value>) -> Value {
        get {
            entries[key.propertyID].map { $0.value[as: Value.self] } ?? key.defaultValue
        }
        set {
            entries[key.propertyID] = _EnvironmentSlot(newValue)
        }
    }
}
