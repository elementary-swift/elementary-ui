/// Marks a class as reactive, enabling automatic dependency tracking for its properties.
///
/// Apply this macro to a class to make it participate in the reactivity system. The macro:
/// - Automatically makes stored properties reactive and trackable
/// - Conforms the class to ``ReactiveObject``
/// - Sets up the infrastructure for change tracking
///
/// ## Usage
///
/// ```swift
/// @Reactive
/// class Counter {
///     var count: Int = 0  // Automatically becomes reactive
///     var name: String = "Counter"  // Also reactive
/// }
/// ```
///
/// When a reactive property changes, any tracking scopes (created with ``withReactiveTracking(_:onChange:)``)
/// that accessed the property will be notified.
///
/// - Important: Only use this macro on classes, not structs or other types.
@attached(member, names: named(_$reactivity))
@attached(memberAttribute)
@attached(extension, conformances: ReactiveObject)
public macro Reactive() = #externalMacro(module: "ReactivityMacros", type: "ReactiveMacro")

/// Makes a property within a ``Reactive()`` class participate in dependency tracking.
///
/// This macro is automatically applied by ``Reactive()`` to stored properties in reactive classes.
/// You don't need to apply this macro yourself - it's an implementation detail of the reactivity system.
///
/// When a property is accessed within a ``withReactiveTracking(_:onChange:)`` scope,
/// the scope will be notified when the property changes.
///
/// The macro generates custom getters/setters that register property access and changes,
/// enabling automatic dependency tracking. `propertyIndex` is assigned by ``Reactive()``.
@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_), prefixed($propertyID_))
public macro ReactiveProperty(propertyIndex: Int? = nil) = #externalMacro(module: "ReactivityMacros", type: "ReactivePropertyMacro")

/// Excludes a property from reactive tracking while still allowing change notifications.
///
/// Apply this macro to properties within a ``Reactive()`` class that should not participate
/// in dependency tracking but still need to trigger reactivity updates when changed.
///
/// ## Usage
///
/// ```swift
/// @Reactive
/// class ViewModel {
///     var count: Int = 0  // Automatically reactive
///     @ReactiveIgnored var debugInfo: String = ""  // Changes won't trigger tracking
/// }
/// ```
///
/// This is useful for properties that:
/// - Are internal implementation details
/// - Change frequently without affecting rendered output
/// - Are used for debugging or logging
///
/// - Important: This macro should only be used within a class marked with ``Reactive()``.
@attached(accessor, names: named(willSet))
public macro ReactiveIgnored() = #externalMacro(module: "ReactivityMacros", type: "ReactiveIgnoredMacro")
