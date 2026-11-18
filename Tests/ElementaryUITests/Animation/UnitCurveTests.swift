import Testing

@testable import ElementaryUI

@Suite
struct UnitCurveTests {
    @Test
    func linearIsIdentity() {
        for t in stride(from: 0.0, through: 1.0, by: 0.125) {
            #expect(UnitCurve.linear.value(at: t) == Float(t))
            #expect(UnitCurve.linear.velocity(at: t) == 1)
        }
    }

    @Test(arguments: [
        (0.1, 0.019722), (0.25, 0.129162), (0.5, 0.5), (0.75, 0.870838), (0.9, 0.980278),
    ])
    func easeInOutMatchesCSS(t: Double, expected: Float) {
        #expect(isClose(UnitCurve.easeInOut.value(at: t), expected))
    }

    @Test(arguments: [
        (0.1, 0.017027), (0.25, 0.093465), (0.5, 0.315357), (0.75, 0.621862), (0.9, 0.839428),
    ])
    func easeInMatchesCSS(t: Double, expected: Float) {
        #expect(isClose(UnitCurve.easeIn.value(at: t), expected))
    }

    @Test(arguments: [
        (0.1, 0.160572), (0.25, 0.378138), (0.5, 0.684643), (0.75, 0.906535), (0.9, 0.982973),
    ])
    func easeOutMatchesCSS(t: Double, expected: Float) {
        #expect(isClose(UnitCurve.easeOut.value(at: t), expected))
    }

    @Test(arguments: [
        (0.1, 0.094796), (0.25, 0.408511), (0.5, 0.802403), (0.75, 0.960459), (0.9, 0.994316),
    ])
    func cssEaseMatchesCSS(t: Double, expected: Float) {
        #expect(isClose(ControlPoints.cssEase.curve.value(at: t), expected))
    }

    @Test(arguments: ControlPoints.all + [ControlPoints(0.7, -0.4, 0.4, 1.4)])
    func valueAtXOfParameterIsYOfParameter(points: ControlPoints) {
        for s in stride(from: Float(0), through: 1, by: 0.05) {
            let x = cubicBezier(p1: points.x1, p2: points.x2, at: s)
            let y = cubicBezier(p1: points.y1, p2: points.y2, at: s)
            #expect(isClose(points.curve.value(at: Double(x)), y), "s = \(s)")
        }
    }

    @Test(arguments: ControlPoints.all)
    func endpointsAreFixedAndOutOfRangeTimeIsClamped(points: ControlPoints) {
        let curve = points.curve
        #expect(curve.value(at: 0) == 0)
        #expect(curve.value(at: 1) == 1)
        #expect(curve.value(at: -0.5) == 0)
        #expect(curve.value(at: 1.5) == 1)
    }

    @Test
    func curveWhoseXIsLinearInTheParameterIsUnchanged() {
        let curve = UnitCurve.bezier(x1: 1.0 / 3.0, y1: 0, x2: 2.0 / 3.0, y2: 1)
        for t in stride(from: 0.0, through: 1.0, by: 0.05) {
            let s = Float(t)
            let smoothstep = 3 * s * s - 2 * s * s * s
            #expect(isClose(curve.value(at: t), smoothstep, tolerance: 1e-6), "t = \(t)")
        }
    }

    @Test(arguments: ControlPoints.all)
    func isMonotonicInTime(points: ControlPoints) {
        let curve = points.curve
        var previous = curve.value(at: 0)
        for t in stride(from: 0.01, through: 1.0, by: 0.01) {
            let value = curve.value(at: t)
            #expect(value >= previous, "t = \(t)")
            previous = value
        }
    }

    @Test(arguments: [
        (0.1, 0.402244), (0.25, 1.059262), (0.5, 1.724138), (0.75, 1.059262), (0.9, 0.402244),
    ])
    func easeInOutVelocityIsSlopeInTime(t: Double, expected: Float) {
        #expect(isClose(UnitCurve.easeInOut.velocity(at: t), expected))
    }

    @Test(arguments: ControlPoints.all)
    func velocityMatchesFiniteDifferenceOfValue(points: ControlPoints) {
        let curve = points.curve
        let h = 1e-3
        for t in stride(from: 0.05, through: 0.95, by: 0.05) {
            let slope = (curve.value(at: t + h) - curve.value(at: t - h)) / Float(2 * h)
            #expect(isClose(curve.velocity(at: t), slope, tolerance: 1e-2), "t = \(t)")
        }
    }

    @Test(arguments: [ControlPoints.easeIn, .easeOut, ControlPoints(0, 0.5, 1, 0.5), ControlPoints(1, 0, 0, 1)])
    func velocityIsFiniteWhereXHasAZeroSlope(points: ControlPoints) {
        for t in [0.0, 0.5, 1.0] {
            #expect(points.curve.velocity(at: t).isFinite, "t = \(t)")
        }
    }

    @Test(arguments: [
        (ControlPoints(-0.5, 0.2, 1.5, 0.8), ControlPoints(0, 0.2, 1, 0.8)),
        (ControlPoints(1.4, 0, -0.3, 1), ControlPoints(1, 0, 0, 1)),
    ])
    func xControlPointsAreClampedToUnitInterval(given: ControlPoints, clamped: ControlPoints) {
        for t in stride(from: 0.0, through: 1.0, by: 0.05) {
            #expect(given.curve.value(at: t) == clamped.curve.value(at: t), "t = \(t)")
        }
    }

    @Test
    func springInterruptingAnEaseInheritsVelocityPerSecond() {
        var context = AnimationContext()
        let merged = Animation.smooth.shouldMerge(
            previous: .easeInOut(duration: 2),
            value: Float(10).animatableVector,
            time: 1,
            context: &context
        )
        #expect(merged)
        let velocity = context.initialVelocity.map { Float(_animatableVector: $0) }
        #expect(velocity.map { isClose($0, 10 * 1.724138 / 2) } == true)
    }

    @Test
    func easeInAnimationFollowsTheCSSCurve() {
        var value = AnimatedValue(value: Float(0))
        value.animate(to: 100, startTime: 0, animation: .easeIn(duration: 1))
        value.progressToTime(0.5)
        #expect(isClose(value.presentation, 31.5357, tolerance: 1e-2))
    }
}

struct ControlPoints: Sendable, CustomTestStringConvertible {
    var x1: Float, y1: Float, x2: Float, y2: Float

    init(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) {
        (self.x1, self.y1, self.x2, self.y2) = (x1, y1, x2, y2)
    }

    static let easeInOut = Self(0.42, 0, 0.58, 1)
    static let easeIn = Self(0.42, 0, 1, 1)
    static let easeOut = Self(0, 0, 0.58, 1)
    static let cssEase = Self(0.25, 0.1, 0.25, 1)
    static let all = [easeInOut, easeIn, easeOut, cssEase]

    var curve: UnitCurve { .bezier(x1: x1, y1: y1, x2: x2, y2: y2) }

    var testDescription: String { "cubic-bezier(\(x1), \(y1), \(x2), \(y2))" }
}

private func cubicBezier(p1: Float, p2: Float, at s: Float) -> Float {
    let r = 1 - s
    return 3 * r * r * s * p1 + 3 * r * s * s * p2 + s * s * s
}

private func isClose(_ actual: Float, _ expected: Float, tolerance: Float = 1e-4) -> Bool {
    abs(actual - expected) <= tolerance
}
