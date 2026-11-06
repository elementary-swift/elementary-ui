import Reactivity
import _UTF8Internals

public extension View {
    /// Sets an environment value for this view and its descendants.
    ///
    /// Use this modifier to provide values that descendant views can read using the
    /// `@Environment` property wrapper. The value is available to all views in the
    /// subtree.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// extension EnvironmentValues {
    ///     @Entry var theme: Theme = .light
    /// }
    ///
    /// @View
    /// struct App {
    ///     @State var currentTheme: Theme = .light
    ///
    ///     var body: some View {
    ///         ContentView()
    ///             .environment(#Key(\.theme), currentTheme)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: The key identifying the environment value to set.
    ///   - value: The value to set for the environment key.
    /// - Returns: A view that provides the environment value to its descendants.
    consuming func environment<V>(_ key: EnvironmentValues._Key<V>, _ value: V) -> _EnvironmentView<V, Self> {
        _EnvironmentView(wrapped: self, key: key, value: value, isEqual: nil)
    }

    /// Sets an environment value for this view and its descendants.
    ///
    /// This overload is optimized for `Equatable` values, enabling efficient updates
    /// when the value changes.
    ///
    /// - Parameters:
    ///   - key: The key identifying the environment value to set.
    ///   - value: The equatable value to set for the environment key.
    /// - Returns: A view that provides the environment value to its descendants.
    consuming func environment<V>(_ key: EnvironmentValues._Key<V>, _ value: V) -> _EnvironmentView<V, Self>
    where V: Equatable {
        _EnvironmentView(wrapped: self, key: key, value: value, isEqual: ==)
    }

    /// Sets a string environment value for this view and its descendants.
    ///
    /// This overload is optimized for `String` values, using UTF-8 comparison
    /// for efficient updates.
    ///
    /// - Parameters:
    ///   - key: The key identifying the environment value to set.
    ///   - value: The string value to set for the environment key.
    /// - Returns: A view that provides the environment value to its descendants.
    consuming func environment(_ key: EnvironmentValues._Key<String>, _ value: String) -> _EnvironmentView<String, Self> {
        _EnvironmentView(wrapped: self, key: key, value: value, isEqual: String.utf8Equals)
    }

    /// Sets an environment value for this view and its descendants.
    ///
    /// This overload is optimized for reference types that are also `Equatable`,
    /// using identity comparison for efficient updates.
    ///
    /// - Parameters:
    ///   - key: The key identifying the environment value to set.
    ///   - value: The reference value to set for the environment key.
    /// - Returns: A view that provides the environment value to its descendants.
    consuming func environment<V>(_ key: EnvironmentValues._Key<V>, _ value: V) -> _EnvironmentView<V, Self>
    where V: Equatable & AnyObject {
        _EnvironmentView(wrapped: self, key: key, value: value, isEqual: ===)
    }

    /// Sets an environment value for this view and its descendants.
    ///
    /// This overload is optimized for reference types, using identity comparison
    /// for efficient updates.
    ///
    /// - Parameters:
    ///   - key: The key identifying the environment value to set.
    ///   - value: The reference value to set for the environment key.
    /// - Returns: A view that provides the environment value to its descendants.
    consuming func environment<V>(_ key: EnvironmentValues._Key<V>, _ value: V) -> _EnvironmentView<V, Self>
    where V: AnyObject {
        _EnvironmentView(wrapped: self, key: key, value: value, isEqual: ===)
    }

    /// Sets a reactive object in the environment for this view and its descendants.
    ///
    /// Use this modifier to provide reactive objects (marked with `@Reactive`) to descendant
    /// views. The object can be accessed using `@Environment` and will automatically
    /// trigger updates when its reactive properties change.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Reactive
    /// class AppState {
    ///     var user: User? = nil
    /// }
    ///
    /// @View
    /// struct App {
    ///     let state = AppState()
    ///
    ///     var body: some View {
    ///         ContentView()
    ///             .environment(state)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter object: The reactive object to provide in the environment.
    /// - Returns: A view that provides the reactive object to its descendants.
    consuming func environment<V: ReactiveObject>(_ object: V) -> _EnvironmentView<V, Self> {
        _EnvironmentView(wrapped: self, key: V.environmentKey, value: object, isEqual: ===)
    }
}

public struct _EnvironmentView<V, Wrapped: View>: View {
    public typealias _MountedNode = _StatefulNode<_EnvironmentSlot, Wrapped._MountedNode>
    public typealias Tag = Wrapped.Tag

    let wrapped: Wrapped
    let key: EnvironmentValues._Key<V>
    let value: V
    let isEqual: ((V, V) -> Bool)?

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        var context = copy context
        let slot = _EnvironmentSlot(view.value)
        context.environment.entries[view.key.propertyID] = slot

        return .init(state: slot, child: Wrapped._makeNode(view.wrapped, context: context, ctx: &ctx))
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        let slot = node.state
        let isUnchanged = view.isEqual?(slot.value[as: V.self], view.value) ?? true
        slot.value[as: V.self] = view.value
        if !isUnchanged {
            // Readers update in this transaction, before or while the subtree is patched.
            slot.dependents.invalidateAll(&tx)
        }

        Wrapped._patchNode(view.wrapped, node: &node.child, tx: &tx)
    }
}

#if !hasFeature(Embedded)
extension _EnvironmentView {
    public static func _render<Renderer: _HTMLRendering>(
        _ html: consuming Self,
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) {
        let view = html
        _ServerRenderStore.withValue(view.value, for: view.key) {
            Wrapped._render(view.wrapped, into: &renderer, with: copy context)
        }
    }

    public static func _render<Renderer: _AsyncHTMLRendering>(
        _ html: consuming Self,
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) async throws {
        let view = html
        try await _ServerRenderStore.withValue(view.value, for: view.key) {
            try await Wrapped._render(view.wrapped, into: &renderer, with: copy context)
        }
    }
}
#endif
