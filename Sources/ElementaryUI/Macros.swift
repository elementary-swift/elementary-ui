/// Marks a struct as a view, enabling it to be used in the view hierarchy.
///
/// Use the `var body` property to define the view's content.
///
/// Apply this macro to a struct to make it conform to the ``View`` protocol and enable
/// automatic state management. The macro generates the necessary infrastructure for:
/// - View lifecycle management
/// - ``State`` and ``Environment`` property handling
/// - Equality checking for efficient updates
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
@attached(
    extension,
    conformances: __FunctionView,
    View,
    SVGView,
    __ViewEquatable,
    names: named(__initializeState),
    named(__restoreState),
    named(__applyContext),
    named(__ViewState),
    named(_MountedNode),
    named(__arePropertiesEqual)
)
@attached(memberAttribute)
public macro View() = #externalMacro(module: "ElementaryUIMacros", type: "ViewMacro")

/// Creates an environment key from a key path to an environment value.
///
/// Use this macro to create a typed key for accessing environment values. This is typically
/// used when defining custom environment values or when you need to reference an environment
/// key directly.
///
/// ## Usage
///
/// ```swift
/// extension EnvironmentValues {
///     @Entry var customValue: String = "default"
/// }
///
/// view.environment(#Key(\.customValue), "new value")
/// ```
///
/// - Parameter keyPath: A key path to a property on ``EnvironmentValues``.
/// - Returns: A typed environment key that can be used with ``View/environment(_:_:)``.
@freestanding(expression)
public macro Key<Value>(_: KeyPath<EnvironmentValues, Value>) -> EnvironmentValues._Key<Value> =
    #externalMacro(module: "ElementaryUIMacros", type: "EnvironmentKeyMacro")

/// Creates a binding to a nested property for two-way data flow.
///
/// Use this macro to create a ``Binding`` to nested properties in situations where
/// key-path syntax is not available (such as in embedded Swift). The expression must
/// be both readable and writable.
///
/// ## Usage
///
/// For simple state variables, use the `$` syntax:
/// ```swift
/// @State var text: String = ""
/// TextField(text: $text)  // Use $state for simple properties
/// ```
///
/// For nested properties, use `#Binding`:
/// ```swift
/// @View
/// struct UserEditor {
///     @State var user: User = User()
///
///     var body: some View {
///         div {
///             TextField(text: #Binding(user.name))
///             TextField(text: #Binding(user.email))
///             NumberField(value: #Binding(user.age))
///         }
///     }
/// }
/// ```
///
/// - Parameter valueExpression: A readable and writable nested property expression.
/// - Returns: A ``Binding`` that can read and write to the nested property.
@freestanding(expression)
public macro Binding<Value>(_ valueExpression: Value) -> Binding<Value> =
    #externalMacro(module: "ElementaryUIMacros", type: "BindingMacro")

/// Marks a property as an environment value entry.
///
/// Apply this macro to properties in an extension of ``EnvironmentValues`` to define
/// custom environment values that can be passed down the view hierarchy.
///
/// ## Usage
///
/// ```swift
/// extension EnvironmentValues {
///     @Entry var theme: Theme = .light
///     @Entry var apiClient: APIClient = APIClient()
/// }
///
/// // Use in views marked with @View
/// @View
/// struct MyView {
///     @Environment(#Key(\.theme)) var theme
///
///     var body: some View {
///         div { "Current theme: \(theme)" }
///     }
/// }
/// ```
@attached(accessor, names: named(get), named(set))
@attached(peer, names: prefixed(_$key_))
public macro Entry() = #externalMacro(module: "ElementaryUIMacros", type: "EntryMacro")
