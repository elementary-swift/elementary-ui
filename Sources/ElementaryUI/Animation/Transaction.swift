import _ThreadLocal

/// A context for applying animations and other changes to the view hierarchy.
///
/// `Transaction` defines how state changes are applied to views, including
/// whether animations should be used and which animation to apply.
///
/// ## Using Transactions
///
/// Typically, you don't create transactions directly. Instead, use ``withAnimation(_:_:)``
/// or ``withTransaction(_:_:)`` to wrap state changes:
///
/// ```swift
/// withAnimation(.smooth) {
///     isExpanded = true
///     offset = 100
/// }
/// ```
///
/// ## Animation Completion
///
/// Track when animations complete using completion callbacks:
///
/// ```swift
/// withAnimation(.smooth, completionCriteria: .logicallyComplete, {
///     position = targetPosition
/// }, completion: {
///     print("Animation completed")
/// })
/// ```
public struct Transaction {
    // NOTE: do not let this get too big, it is passed around a lot

    let _animationTracker: AnimationTracker = .init()

    /// The animation to apply to state changes made within this transaction.
    ///
    /// Set this to `nil` to disable animation. When non-nil, animated properties
    /// will interpolate to their new values using the specified animation.
    public var animation: Animation?

    public var disablesAnimation: Bool = false

    /// Creates a new transaction with an optional animation.
    ///
    /// - Parameter animation: The animation to apply to state changes, or `nil` for no animation.
    public init(animation: Animation? = nil) {
        self.animation = animation
    }

    /// Adds a callback to be executed when animations in this transaction complete.
    ///
    /// Use this method to perform actions after animations finish:
    ///
    /// ```swift
    /// let transaction = Transaction(animation: .smooth)
    /// transaction.addAnimationCompletion {
    ///     print("Animation done!")
    /// }
    /// withTransaction(transaction) {
    ///     offset = 100
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - criteria: The criteria for when the completion callback should be called.
    ///     Default is ``AnimationCompletionCriteria/logicallyComplete``.
    ///   - onComplete: The closure to execute when the criteria is met.
    public func addAnimationCompletion(
        criteria: AnimationCompletionCriteria = .logicallyComplete,
        _ onComplete: @escaping () -> Void
    ) {
        _animationTracker.addAnimationCompletion(criteria: criteria, onComplete)
    }

    // TODO: extendable storage via typed keys
}

/// Executes a closure with a specific transaction.
///
/// Use this function to apply a custom ``Transaction`` to state changes:
///
/// ```swift
/// var transaction = Transaction(animation: .smooth)
///
/// withTransaction(transaction) {
///     count += 1
///     isVisible = false
/// }
/// ```
///
/// - Parameters:
///   - transaction: The transaction to use for state changes.
///   - body: A closure containing the state changes to animate.
/// - Returns: The result of executing the body closure.
/// - Throws: Rethrows any error thrown by the body closure.
public func withTransaction<Result, Failure>(
    _ transaction: Transaction,
    _ body: () throws(Failure) -> Result
) throws(Failure) -> Result {
    try withUnsafePointer(to: transaction) { (pointer) throws(Failure) -> Result in
        let previous = Transaction.slot.value
        Transaction.slot.value = UnsafeMutableRawPointer(mutating: pointer)
        defer { Transaction.slot.value = previous }
        return try body()
    }
}

/// Executes a closure with animation.
///
/// Use this function to animate state changes. All animatable properties
/// changed within the closure will interpolate to their new values using
/// the specified animation.
///
/// ## Usage
///
/// ```swift
/// withAnimation(.smooth) {
///     isExpanded = true
///     height = 200
/// }
///
/// // With a custom animation
/// withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
///     rotation = 360
/// }
/// ```
///
/// - Parameters:
///   - animation: The animation to apply. Default is ``Animation/default``.
///   - body: A closure containing the state changes to animate.
/// - Returns: The result of executing the body closure.
/// - Throws: Rethrows any error thrown by the body closure.
public func withAnimation<Result, Failure>(
    _ animation: Animation? = .default,
    _ body: () throws(Failure) -> Result
) throws(Failure) -> Result {
    try withTransaction(.init(animation: animation), body)
}

/// Executes a closure with animation and a completion handler.
///
/// Use this function when you need to perform an action after the animation completes:
///
/// ```swift
/// withAnimation(.smooth, {
///     position = targetPosition
/// }, completion: {
///     print("Movement complete")
///     canInteract = true
/// })
/// ```
///
/// - Parameters:
///   - animation: The animation to apply. Default is ``Animation/default``.
///   - completionCriteria: When the completion handler should be called.
///     Default is ``AnimationCompletionCriteria/logicallyComplete``.
///   - body: A closure containing the state changes to animate.
///   - completion: A closure to execute when the animation completes.
/// - Returns: The result of executing the body closure.
/// - Throws: Rethrows any error thrown by the body closure.
public func withAnimation<Result, Failure>(
    _ animation: Animation? = .default,
    completionCriteria: AnimationCompletionCriteria = .logicallyComplete,
    _ body: () throws(Failure) -> Result,
    completion: @escaping () -> Void
) throws(Failure) -> Result {
    let transaction = Transaction(animation: animation)
    transaction.addAnimationCompletion(criteria: completionCriteria, completion)
    return try withTransaction(transaction, body)
}

/// Criteria for determining when an animation completion callback should be executed.
///
/// Use this type to control when completion handlers are called for animations
/// created with ``withAnimation(_:completionCriteria:_:completion:)``.
public struct AnimationCompletionCriteria: Hashable {
    internal enum Value {
        case logicallyComplete
        case removed
    }

    internal var value: Value

    /// The animation reaches its logical completion point.
    ///
    /// For spring animations, this is typically after one full oscillation period,
    /// even if the value hasn't completely settled. For timing curve animations,
    /// this is when the animation duration completes.
    public static var logicallyComplete: Self {
        .init(value: .logicallyComplete)
    }

    /// The animation has fully completed and is removed.
    ///
    /// Use this criteria when you need to know that both the animation has completed
    /// and the view has been removed from the DOM.
    public static var removed: Self {
        .init(value: .removed)
    }
}

final class AnimationTracker {
    struct Instance {
        private let instanceID: Int
        private let tracker: AnimationTracker

        init(instanceID: Int, tracker: AnimationTracker) {
            self.instanceID = instanceID
            self.tracker = tracker
        }

        func reportLogicallyComplete() {
            tracker.reportLogicallyComplete(instanceID)
        }

        func reportRemoved() {
            tracker.reportRemoved(instanceID)
        }
    }

    private var _nextInstanceID: Int = 0
    private var openRemovals: Set<Int> = []
    private var openCompletions: Set<Int> = []
    private var completionCallbacks: [() -> Void] = []
    private var removalCallbacks: [() -> Void] = []

    var areAllCallbacksRun: Bool {
        completionCallbacks.isEmpty && removalCallbacks.isEmpty
    }

    func addAnimation() -> Instance {
        _nextInstanceID &+= 1
        let instanceID = _nextInstanceID
        openRemovals.insert(instanceID)
        openCompletions.insert(instanceID)

        return Instance(instanceID: _nextInstanceID, tracker: self)
    }

    private func reportLogicallyComplete(_ instanceID: Int) {
        openCompletions.remove(instanceID)
        checkCallbacks()
    }

    private func reportRemoved(_ instanceID: Int) {
        openCompletions.remove(instanceID)
        openRemovals.remove(instanceID)
        checkCallbacks()
    }

    func addAnimationCompletion(criteria: AnimationCompletionCriteria = .logicallyComplete, _ onComplete: @escaping () -> Void) {
        switch criteria.value {
        case .logicallyComplete:
            completionCallbacks.append(onComplete)
        case .removed:
            removalCallbacks.append(onComplete)
        }
    }

    func checkCallbacks() {
        if openCompletions.isEmpty {
            for callback in completionCallbacks {
                callback()
            }
            completionCallbacks.removeAll()
        }

        if openRemovals.isEmpty {
            for callback in removalCallbacks {
                callback()
            }

            removalCallbacks.removeAll()
        }
    }

    deinit {
        for callback in completionCallbacks {
            callback()
        }
        for callback in removalCallbacks {
            callback()
        }
    }
}

extension Transaction {
    nonisolated(unsafe) static var slot = ThreadLocalSlot()

    static var _current: Transaction? {
        slot.value?.assumingMemoryBound(to: Transaction.self).pointee
    }
}
