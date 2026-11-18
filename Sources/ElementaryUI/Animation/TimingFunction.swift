public struct UnitCurve {
    private enum Storage {
        case linear
        case bezier(x1: Float, y1: Float, x2: Float, y2: Float)
    }

    private let storage: Storage

    public func value(at time: Double) -> Float {
        let t = clamped(time)
        switch storage {
        case .linear:
            return t
        case let .bezier(x1, y1, x2, y2):
            let x = BezierAxis(x1, x2)
            return BezierAxis(y1, y2).value(at: x.parameter(forValue: t))
        }
    }

    public func velocity(at time: Double) -> Float {
        let t = clamped(time)
        switch storage {
        case .linear:
            return 1.0
        case let .bezier(x1, y1, x2, y2):
            let x = BezierAxis(x1, x2)
            let y = BezierAxis(y1, y2)
            let s = x.parameter(forValue: t)
            let dxds = x.slope(at: s)
            if dxds > BezierAxis.flatSlope {
                return y.slope(at: s) / dxds
            }
            let step: Float = 1e-3
            let s0 = max(s - step, 0)
            let s1 = min(s + step, 1)
            let dx = x.value(at: s1) - x.value(at: s0)
            return dx > 0 ? (y.value(at: s1) - y.value(at: s0)) / dx : 0
        }
    }

    private func clamped(_ value: Double) -> Float {
        Float(min(max(value, 0.0), 1.0))
    }
}

private struct BezierAxis {
    static let flatSlope: Float = 1e-6

    let a: Float
    let b: Float
    let c: Float

    init(_ p1: Float, _ p2: Float) {
        c = 3 * p1
        b = 3 * (p2 - p1) - c
        a = 1 - c - b
    }

    func value(at s: Float) -> Float {
        ((a * s + b) * s + c) * s
    }

    func slope(at s: Float) -> Float {
        (3 * a * s + 2 * b) * s + c
    }

    func parameter(forValue target: Float) -> Float {
        let tolerance: Float = 1e-6
        var s = target
        for _ in 0..<8 {
            let error = value(at: s) - target
            if abs(error) < tolerance { return s }
            let d = slope(at: s)
            if abs(d) < Self.flatSlope { break }
            s -= error / d
            if s < 0 || s > 1 { break }
        }

        var low: Float = 0
        var high: Float = 1
        s = target
        for _ in 0..<32 {
            let error = value(at: s) - target
            if abs(error) < tolerance { return s }
            if error > 0 { high = s } else { low = s }
            s = (low + high) / 2
        }
        return s
    }
}

extension UnitCurve {
    // Linear cubic-bezier fast path: cubic-bezier(1/3, 1/3, 2/3, 2/3)
    public static let linear: Self = .init(storage: .linear)

    public static func bezier(x1: Float, y1: Float, x2: Float, y2: Float) -> Self {
        .init(storage: .bezier(x1: min(max(x1, 0), 1), y1: y1, x2: min(max(x2, 0), 1), y2: y2))
    }

    public static let easeInOut: Self = .bezier(x1: 0.42, y1: 0.0, x2: 0.58, y2: 1.0)
    public static let easeIn: Self = .bezier(x1: 0.42, y1: 0.0, x2: 1.0, y2: 1.0)
    public static let easeOut: Self = .bezier(x1: 0.0, y1: 0.0, x2: 0.58, y2: 1.0)
}

struct TimingFunction {
    var curve: UnitCurve
    var duration: Double
}

extension TimingFunction: CustomAnimation {
    func animate(value: AnimatableVector, time: Double, context: inout AnimationContext) -> AnimatableVector? {
        guard time <= duration else {
            return nil
        }

        let t = time / duration
        let factor = curve.value(at: t)
        return value * factor
    }

    func velocity(value: AnimatableVector, time: Double, context: AnimationContext) -> AnimatableVector? {
        guard time <= duration, duration > 0 else {
            return nil
        }

        let t = time / duration
        let velocityFactor = curve.velocity(at: t) / Float(duration)
        return value * velocityFactor
    }
}
