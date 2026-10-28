/// A registrar that manages reactive property access tracking and change notifications.
///
/// `ReactivityRegistrar` is the core mechanism used by the ``Reactive()`` macro to integrate
/// objects into the reactivity system. It tracks when properties are accessed within reactive
/// scopes and notifies observers when properties change.
///
/// The ``Reactive()`` macro automatically creates and manages a `ReactivityRegistrar` for you.
/// You typically don't need to use this type directly unless you're building custom reactive primitives.
public struct ReactivityRegistrar: Sendable {
    @usableFromInline
    let tracker = ReactivityTracker()

    /// Creates a new reactivity registrar.
    public init() {}

    /// Registers that a property is being accessed in the current reactive scope.
    ///
    /// Call this method when a property is read to ensure that any active reactive
    /// tracking scope (created with ``withReactiveTracking(_:onChange:)``) can track
    /// this access.
    ///
    /// - Parameter property: The identifier of the property being accessed.
    @inlinable
    public func access(_ property: PropertyID) {
        guard _ThreadLocal.value != nil else { return }
        record(property)
    }

    // Keeps the rarely taken path out of every property getter.
    @usableFromInline
    @inline(never)
    func record(_ property: PropertyID) {
        ReactiveTracking.AccessedDependencies.record(_Access(tracker: tracker, property: property))
    }

    /// Notifies observers that a property is about to change.
    ///
    /// Call this method immediately before a property value is modified. This allows
    /// observers to react before the change takes effect.
    ///
    /// - Parameter property: The identifier of the property about to change.
    @inlinable
    public func willSet(_ property: PropertyID) {
        tracker.notify(property)
    }

    /// Notifies observers that a property has changed.
    ///
    /// Call this method immediately after a property value is modified. This allows
    /// observers to react to the new value.
    ///
    /// - Parameter property: The identifier of the property that changed.
    /// - Note: Observers are notified in ``willSet(_:)``; this call does nothing.
    @inlinable
    public func didSet(_ property: PropertyID) {}
}

extension ReactivityRegistrar: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
    public func hash(into hasher: inout Hasher) {}
}

/// A protocol that marks a class as participating in the reactivity system.
///
/// Classes conforming to `ReactiveObject` can have their properties tracked by the
/// reactivity system. This protocol is automatically conformed to when you apply
/// the ``Reactive()`` macro to a class.
///
/// ## Usage
///
/// You don't conform to this protocol directly. Instead, use the ``Reactive()`` macro:
///
/// ```swift
/// @Reactive
/// class Counter {
///     var count: Int = 0  // Automatically reactive
/// }
/// ```
///
/// The macro adds the `ReactiveObject` conformance for you.
///
/// - Important: Only classes can conform to `ReactiveObject`.
public protocol ReactiveObject: AnyObject {}
