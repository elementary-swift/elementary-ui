import _ElementaryMath

/// A spring animation configuration that defines the physical properties of a spring.
/// Similar to SwiftUI's Spring but uses AnimatableVector as the value type.
public struct Spring {
    /// Damping regime of the system, precomputed with an epsilon threshold.
    private enum DampingRegime {
        case underdamped, criticallyDamped, overdamped

        init(dampingRatio: Double) {
            if abs(dampingRatio - 1.0) < 1e-6 {
                self = .criticallyDamped
            } else if dampingRatio < 1.0 {
                self = .underdamped
            } else {
                self = .overdamped
            }
        }
    }

    /// The damping ratio (ζ) of the spring system.
    /// 0 = undamped, 1 = critically damped, >1 = overdamped
    public let dampingRatio: Double

    /// The natural frequency (ω₀) of the spring system in rad/s.
    public let naturalFrequency: Double

    internal var logicalDuration: Double {
        2.0 * .pi / naturalFrequency
    }

    /// pre-calculated damping regime
    private var regime: DampingRegime

    private init(dampingRatio: Double, naturalFrequency: Double) {
        self.dampingRatio = dampingRatio
        self.naturalFrequency = naturalFrequency
        self.regime = DampingRegime(dampingRatio: dampingRatio)
    }

    public init(
        mass: Double = 1.0,
        stiffness: Double,
        damping: Double,
        allowOverDamping: Bool = false
    ) {
        precondition(mass > 0, "Spring.mass must be > 0")
        precondition(stiffness > 0, "Spring.stiffness must be > 0")
        precondition(damping >= 0, "Spring.damping must be >= 0")
        let actualDamping: Double

        // Clamp damping to prevent over-damping if not allowed
        if !allowOverDamping {
            let criticalDamping = 2.0 * (stiffness * mass).squareRoot()
            actualDamping = min(damping, criticalDamping)
        } else {
            actualDamping = damping
        }

        // Calculate derived physics values
        self.init(
            dampingRatio: actualDamping / (2.0 * (stiffness * mass).squareRoot()),
            naturalFrequency: (stiffness / mass).squareRoot()
        )
    }

    public init(duration: Double = 0.5, bounce: Double = 0.0) {
        let clampedBounce = min(max(bounce, -1.0), 1.0)
        let safeDuration = max(duration, 1e-6)
        self.init(
            dampingRatio: 1.0 - clampedBounce,
            naturalFrequency: 2.0 * .pi / safeDuration
        )
    }
}

extension Spring {
    public func value(target: AnimatableVector, initialVelocity: AnimatableVector, time: Double) -> AnimatableVector {
        switch regime {
        case .criticallyDamped:
            // Critically damped: starts at 0, approaches target
            let envelope = exp(-naturalFrequency * time)
            let factor = 1.0 - envelope * (1.0 + naturalFrequency * time)
            let velocityFactor = envelope * time

            return target * Float(factor) + initialVelocity * Float(velocityFactor)

        case .underdamped:
            // Underdamped: starts at 0, approaches target with oscillation
            let omegaD = naturalFrequency * (1.0 - dampingRatio * dampingRatio).squareRoot()
            let envelope = exp(-dampingRatio * naturalFrequency * time)
            let cosine = cos(omegaD * time)
            let sine = sin(omegaD * time)

            let factor = 1.0 - envelope * (cosine + (dampingRatio * naturalFrequency / omegaD) * sine)
            let velocityFactor = envelope * sine / omegaD

            return target * Float(factor) + initialVelocity * Float(velocityFactor)

        case .overdamped:
            // Overdamped: starts at 0, approaches target without oscillation
            let discriminant = (dampingRatio * dampingRatio - 1.0).squareRoot()
            let r1 = -naturalFrequency * (dampingRatio + discriminant)
            let r2 = -naturalFrequency * (dampingRatio - discriminant)

            let exp1 = exp(r1 * time)
            let exp2 = exp(r2 * time)

            // Position: x(t) = target * [1 - (r2 e^{r1 t} - r1 e^{r2 t}) / (r2 - r1)]
            //                 + v0 * (e^{r1 t} - e^{r2 t}) / (r1 - r2)
            let targetFactor = 1.0 - ((r2 * exp1 - r1 * exp2) / (r2 - r1))
            let velocityFactor = (exp1 - exp2) / (r1 - r2)

            return target * Float(targetFactor) + initialVelocity * Float(velocityFactor)
        }
    }

    public func velocity(target: AnimatableVector, initialVelocity: AnimatableVector, time: Double) -> AnimatableVector {
        switch regime {
        case .underdamped:
            // Underdamped velocity
            let omegaD = naturalFrequency * (1.0 - dampingRatio * dampingRatio).squareRoot()
            let envelope = exp(-dampingRatio * naturalFrequency * time)
            let cosine = cos(omegaD * time)
            let sine = sin(omegaD * time)

            let targetVelocityFactor = envelope * (naturalFrequency * naturalFrequency / omegaD) * sine
            let initialVelocityFactor = envelope * (cosine - (dampingRatio * naturalFrequency / omegaD) * sine)

            return target * Float(targetVelocityFactor) + initialVelocity * Float(initialVelocityFactor)

        case .criticallyDamped:
            // Critically damped velocity
            let envelope = exp(-naturalFrequency * time)
            let targetVelocityFactor = envelope * (naturalFrequency * naturalFrequency) * time
            let initialVelocityFactor = envelope * (1.0 - naturalFrequency * time)

            return target * Float(targetVelocityFactor) + initialVelocity * Float(initialVelocityFactor)

        case .overdamped:
            // Overdamped velocity
            let discriminant = (dampingRatio * dampingRatio - 1.0).squareRoot()
            let r1 = -naturalFrequency * (dampingRatio + discriminant)
            let r2 = -naturalFrequency * (dampingRatio - discriminant)

            let exp1 = exp(r1 * time)
            let exp2 = exp(r2 * time)

            // Velocity: x'(t) = target * [ (r1 r2) * (e^{r1 t} - e^{r2 t}) / (r1 - r2) ]
            //                     + v0 * (r1 e^{r1 t} - r2 e^{r2 t}) / (r1 - r2)
            let targetVelocityFactor = (r1 * r2) * (exp1 - exp2) / (r1 - r2)
            let initialVelocityFactor = (r1 * exp1 - r2 * exp2) / (r1 - r2)

            return target * Float(targetVelocityFactor) + initialVelocity * Float(initialVelocityFactor)
        }
    }
}

extension Spring {
    public static var smooth: Self { smooth() }
    public static var snappy: Self { snappy() }
    public static var bouncy: Self { bouncy() }

    public static func smooth(duration: Double = 0.5, extraBounce: Double = 0.0) -> Self {
        .init(duration: duration, bounce: extraBounce + 0.0)
    }

    public static func snappy(duration: Double = 0.5, extraBounce: Double = 0.0) -> Self {
        .init(duration: duration, bounce: extraBounce + 0.15)
    }

    public static func bouncy(duration: Double = 0.5, extraBounce: Double = 0.0) -> Self {
        .init(duration: duration, bounce: extraBounce + 0.3)
    }
}

struct SpringAnimation: CustomAnimation {
    private static let settlingTolerance: Float = 0.001
    let spring: Spring
    let logicalDuration: Double

    init(spring: Spring) {
        self.spring = spring
        self.logicalDuration = spring.logicalDuration
    }

    func animate(value: AnimatableVector, time: Double, context: inout AnimationContext) -> AnimatableVector? {
        // Use the initial velocity from context if available, otherwise use zero velocity
        let velocity = context.initialVelocity ?? AnimatableVector.zero(value)

        let result = spring.value(target: value, initialVelocity: velocity, time: time)

        // THINK: maybe this can be approximated once and then just to a timestamp compare?
        let isSettled = isValueSettled(result, target: value, time: time, context: context)

        if !context.isLogicallyComplete && time > logicalDuration {
            context.isLogicallyComplete = true
        }

        return isSettled ? nil : result
    }

    func velocity(value: AnimatableVector, time: Double, context: AnimationContext) -> AnimatableVector? {
        let velocity = context.initialVelocity ?? AnimatableVector.zero(value)

        return spring.velocity(target: value, initialVelocity: velocity, time: time)
    }

    public func shouldMerge(previous: Animation, value: AnimatableVector, time: Double, context: inout AnimationContext) -> Bool {
        // Calculate velocity from the previous animation at the interruption time
        guard let velocity = previous.velocity(value: value, time: time, context: context) else {
            return false
        }

        context.initialVelocity = velocity
        return true
    }

    private func isValueSettled(
        _ current: AnimatableVector,
        target: AnimatableVector,
        time: Double,
        context: AnimationContext
    ) -> Bool {
        let threshold = Self.settlingTolerance * target.magnitude

        let positionSettled = (current - target).magnitude < threshold

        guard positionSettled else { return false }

        let currentVelocityVector = self.velocity(value: target, time: time, context: context) ?? AnimatableVector.zero(target)
        let velocitySettled = currentVelocityVector.magnitude < threshold

        return positionSettled && velocitySettled
    }
}
