import ElementaryUI
import Testing

// A plain import: conformers outside the module rely on the public defaults.
private struct LinearAnimation: CustomAnimation {
    let duration: Double

    func animate(value: AnimatableVector, time: Double, context: inout AnimationContext) -> AnimatableVector? {
        guard time < duration else { return nil }
        return value * Float(time / duration)
    }
}

struct CustomAnimationTests {
    @Test func conformsWithOnlyAnimate() {
        let animation = Animation(LinearAnimation(duration: 1))
        _ = animation.delay(0.5)
    }
}
