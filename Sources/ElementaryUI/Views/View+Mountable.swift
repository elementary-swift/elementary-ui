// TODO: maybe this should not derive from HTML at all, or maybe HTML should already be "View" and _Mountable is an extra requirement for mounting?
// TODO: think about how to square MainActor-isolation with server side usage

/// A type that represents a part of your app's user interface and can be mounted to the view hierarchy.
///
/// Views are the fundamental building blocks of your app's UI. Each view defines a piece of
/// the interface by implementing a `body` property that returns its content.
///
/// - Important: Always use the ``View()-macro`` macro to create views. The macro sets up the
///   infrastructure needed for state management, environment access, and the view lifecycle.
///
/// ## Creating Views
///
/// You create custom views by applying the `@View` macro to a struct and implementing
/// the `body` property.
///
/// ```swift
/// @View
/// struct GreetingView {
///     @State var name: String = "World"
///
///     var body: some View {
///         div {
///             h1 { "Hello, \(name)!" }
///             input(.type(.text))
///                 .bindValue($name)
///         }
///     }
/// }
/// ```
///
/// ## The Body Property
///
/// The `body` property defines the content of your view. It must return a value that
/// conforms to `View`, which can be:
/// - HTML elements like `div`, `span`, `button`
/// - Other custom views
/// - Modified views like `.onClick`, `.opacity`, `.animation`
/// - Control flow using `if`, `for`, and conditionals
///
/// ## Composing Views
///
/// Build complex interfaces by combining views:
///
/// ```swift
/// @View
/// struct ContentView {
///     var body: some View {
///         div {
///             HeaderView()
///             MainContent()
///             FooterView()
///         }
///     }
/// }
/// ```
public protocol View<Tag>: HTML & _Mountable where Body: HTML & _Mountable {
}

public protocol _Mountable {
    associatedtype _MountedNode: _Reconcilable

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode

    static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    )
}

extension Never: _Mountable {
    public typealias _MountedNode = _EmptyNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        fatalError("This should never be called")
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {}
}
