/// Executes a closure while tracking reactive property accesses, calling a handler when any accessed property changes.
///
/// This function creates a reactive scope that automatically tracks which properties are accessed
/// during execution. When any of those properties change, the `onChange` closure is called once,
/// and tracking is automatically cancelled.
///
/// ## Usage
///
/// ```swift
/// @Reactive
/// class Counter {
///     var count: Int = 0  // Automatically reactive
/// }
///
/// let counter = Counter()
///
/// // Track property accesses and respond to changes
/// withReactiveTracking({
///     print("Count is: \(counter.count)")
/// }, onChange: {
///     print("Count changed!")
/// })
///
/// counter.count = 5  // Prints "Count changed!" and cancels tracking
/// counter.count = 10 // Does not trigger onChange (already cancelled)
/// ```
///
/// - Parameters:
///   - apply: A closure to execute while tracking property accesses.
///   - onChange: A closure to call when any tracked property changes. This is called once,
///               then tracking is automatically cancelled.
///
/// - Returns: The result of executing the `apply` closure.
///
/// - Note: The tracking is cancelled after the first change is detected. For continuous
///         tracking, you'll need to set up a new tracking scope in the `onChange` handler.
public func withReactiveTracking<T>(
    _ apply: () -> T,
    onChange: @autoclosure () -> @Sendable () -> Void
) -> T {
    var result = ReactiveTracking.track(apply)
    if let dependencies = result.dependencies.take() {
        dependencies.observeOnce(onChange())
    }
    return result.takeValue()
}
