/// A description of how a value animates over time.
///
/// `Animation` defines the timing and behavior of animated transitions between values.
/// Use animations with the ``withAnimation(_:_:)`` function or the
/// ``View/animation(_:value:)`` modifier to animate changes.
///
/// ## Creating Animations
///
/// Create animations using static factory methods:
///
/// ```swift
/// // Spring-based animations (recommended)
/// withAnimation(.smooth) {
///     count += 1
/// }
///
/// withAnimation(.snappy(duration: 0.3)) {
///     isVisible.toggle()
/// }
///
/// // Timing curve animations
/// withAnimation(.easeInOut(duration: 0.5)) {
///     offset = 100
/// }
/// ```
///
/// ## Modifying Animations
///
/// Adjust animation timing using modifiers:
///
/// ```swift
/// Animation.smooth
///     .delay(0.2)
///     .speed(2.0)
/// ```
///
/// ## Custom Animations
///
/// Create custom animations by conforming to ``CustomAnimation``:
///
/// ```swift
/// struct MyAnimation: CustomAnimation {
///     func animate(value: AnimatableVector, time: Double, context: inout AnimationContext) -> AnimatableVector? {
///         // Custom animation logic
///     }
/// }
///
/// let animation = Animation(MyAnimation())
/// ```
public struct Animation {
    enum StoredAnimation {
        case spring(SpringAnimation)
        case timingFunction(TimingFunction)
        case any(AnyAnimation)
    }

    var storage: StoredAnimation
    var speed: Double = 1
    var delay: Double = 0

    init(curve: UnitCurve, duration: Double) {
        self.storage = .timingFunction(TimingFunction(curve: curve, duration: duration))
    }

    init(spring: Spring) {
        self.storage = .spring(SpringAnimation(spring: spring))
    }

    /// Creates an animation from a custom animation implementation.
    ///
    /// Use this initializer to create an animation with custom timing and interpolation logic.
    ///
    /// - Parameter customAnimation: A type conforming to ``CustomAnimation``.
    public init(_ customAnimation: some CustomAnimation) {
        self.storage = .any(AnyAnimation(customAnimation))
    }

    func animate(value: AnimatableVector, time: Double, context: inout AnimationContext) -> AnimatableVector? {
        let localTime = localTime(time)

        guard localTime >= 0 else { return AnimatableVector.zero(value) }

        switch storage {
        case .spring(let spring):
            return spring.animate(value: value, time: localTime, context: &context)
        case .timingFunction(let timingFunction):
            return timingFunction.animate(value: value, time: localTime, context: &context)
        case .any(let anyAnimation):
            return anyAnimation.animate(value, localTime, &context)
        }
    }

    func velocity(value: AnimatableVector, time: Double, context: borrowing AnimationContext) -> AnimatableVector? {
        let localTime = localTime(time)

        guard localTime >= 0 else { return AnimatableVector.zero(value) }

        switch storage {
        case .spring(let spring):
            return spring.velocity(value: value, time: localTime, context: context)
        case .timingFunction(let timingFunction):
            return timingFunction.velocity(value: value, time: localTime, context: context)
        case .any(let anyAnimation):
            return anyAnimation.velocity(value, localTime, context)
        }
    }

    func shouldMerge(previous: Animation, value: AnimatableVector, time: Double, context: inout AnimationContext) -> Bool {
        let localTime = localTime(time)

        guard localTime >= 0 else { return true }

        switch storage {
        case .spring(let spring):
            return spring.shouldMerge(previous: previous, value: value, time: time, context: &context)
        case .timingFunction(let timingFunction):
            return timingFunction.shouldMerge(previous: previous, value: value, time: time, context: &context)
        case .any(let anyAnimation):
            return anyAnimation.shouldMerge(previous, value, time, &context)
        }
    }

    @inline(__always)
    private func localTime(_ time: Double) -> Double {
        (time - delay) * speed
    }
}

public extension Animation {
    /// Delays the start of the animation by the specified time.
    ///
    /// Use this method to add a delay before the animation begins:
    ///
    /// ```swift
    /// withAnimation(.smooth.delay(0.3)) {
    ///     showContent = true
    /// }
    /// ```
    ///
    /// Multiple delay calls are cumulative:
    ///
    /// ```swift
    /// Animation.smooth
    ///     .delay(0.1)
    ///     .delay(0.2)  // Total delay: 0.3 seconds
    /// ```
    ///
    /// - Parameter delay: The delay in seconds before the animation starts.
    /// - Returns: An animation with the added delay.
    consuming func delay(_ delay: Double) -> Self {
        var copy = consume self
        copy.delay += delay
        return copy
    }

    /// Multiplies the speed of the animation by the specified factor.
    ///
    /// Use this method to make animations faster or slower:
    ///
    /// ```swift
    /// withAnimation(.smooth.speed(2.0)) {
    ///     // Animation completes in half the time
    ///     position = targetPosition
    /// }
    ///
    /// withAnimation(.smooth.speed(0.5)) {
    ///     // Animation takes twice as long
    ///     opacity = 0
    /// }
    /// ```
    ///
    /// Multiple speed calls are cumulative:
    ///
    /// ```swift
    /// Animation.smooth
    ///     .speed(2.0)
    ///     .speed(0.5)  // Total speed: 1.0 (back to original)
    /// ```
    ///
    /// - Parameter speed: The speed multiplier. Values > 1 make the animation faster,
    ///   values < 1 make it slower.
    /// - Returns: An animation with the modified speed.
    consuming func speed(_ speed: Double) -> Self {
        guard speed != 0 else {
            self.speed = 0
            return self
        }

        var copy = consume self
        copy.delay /= speed
        copy.speed *= speed
        return copy
    }
}

/// Context information available during animation evaluation.
///
/// `AnimationContext` provides state and metadata to custom animations, including
/// initial velocity and completion status.
public struct AnimationContext {
    /// The initial velocity of the animated value, if available.
    ///
    /// Used by spring animations to create smooth transitions when interrupting
    /// an ongoing animation.
    var initialVelocity: AnimatableVector?

    /// Whether the animation has reached its logical completion point.
    ///
    /// For spring animations, this is typically when the spring has completed
    /// one full oscillation period, even if the value hasn't fully settled.
    var isLogicallyComplete: Bool = false
}

/// A protocol for defining custom animation behaviors.
///
/// Conform to this protocol to create animations with custom timing curves
/// and interpolation logic.
///
/// ## Implementation
///
/// ```swift
/// struct BounceAnimation: CustomAnimation {
///     let duration: Double
///
///     func animate(value: AnimatableVector, time: Double, context: inout AnimationContext) -> AnimatableVector? {
///         guard time < duration else {
///             context.isLogicallyComplete = true
///             return nil  // Animation complete
///         }
///
///         let progress = time / duration
///         let bounce = sin(progress * .pi * 4) * (1 - progress)
///         return value * Float(1 + bounce * 0.2)
///     }
/// }
/// ```
public protocol CustomAnimation {
    /// Calculates the animated value at a specific time.
    ///
    /// - Parameters:
    ///   - value: The target value to animate towards.
    ///   - time: The current time in seconds since the animation started.
    ///   - context: The animation context, which can be modified to set completion status.
    /// - Returns: The interpolated value at the given time, or `nil` if the animation is complete.
    func animate(value: AnimatableVector, time: Double, context: inout AnimationContext) -> AnimatableVector?

    /// Calculates the velocity of the animated value at a specific time.
    ///
    /// - Parameters:
    ///   - value: The target value being animated towards.
    ///   - time: The current time in seconds since the animation started.
    ///   - context: The animation context for reading state.
    /// - Returns: The velocity vector at the given time, or `nil` if not applicable.
    func velocity(value: AnimatableVector, time: Double, context: borrowing AnimationContext) -> AnimatableVector?

    /// Determines whether this animation should merge with a previous animation.
    ///
    /// When an animation is interrupted by a new animation, this method determines
    /// whether the new animation should inherit the velocity from the previous animation.
    ///
    /// - Parameters:
    ///   - previous: The animation being interrupted.
    ///   - value: The target value being animated.
    ///   - time: The current time when the interruption occurs.
    ///   - context: The animation context, which can be modified to set initial velocity.
    /// - Returns: `true` if the animations should merge, `false` otherwise.
    func shouldMerge(previous: Animation, value: AnimatableVector, time: Double, context: inout AnimationContext) -> Bool
}

extension CustomAnimation {
    func velocity(at time: Double, context: borrowing AnimationContext) -> AnimatableVector? { nil }
    func shouldMerge(previous: Animation, value: AnimatableVector, time: Double, context: inout AnimationContext) -> Bool { false }
}

struct AnyAnimation {
    var animate: (AnimatableVector, Double, inout AnimationContext) -> AnimatableVector?
    var velocity: (AnimatableVector, Double, borrowing AnimationContext) -> AnimatableVector?
    var shouldMerge: (Animation, AnimatableVector, Double, inout AnimationContext) -> Bool

    init(_ customAnimation: some CustomAnimation) {
        self.animate = customAnimation.animate
        self.velocity = customAnimation.velocity
        self.shouldMerge = customAnimation.shouldMerge
    }
}
