public struct Angle: Equatable, Sendable {
    var degrees: Double
    var radians: Double {
        get {
            degrees * .pi / 180
        }
        set {
            degrees = newValue * 180 / .pi
        }
    }

    public static func radians(_ radians: Double) -> Angle {
        // degrees are probably more common in everyday usage
        Angle(degrees: radians * 180 / .pi)
    }

    public static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }
}

public struct UnitPoint: Equatable, Sendable {
    var x: Float
    var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public static let center: UnitPoint = UnitPoint(x: 0.5, y: 0.5)
    public static let topLeading: UnitPoint = UnitPoint(x: 0, y: 0)
    public static let top: UnitPoint = UnitPoint(x: 0.5, y: 0)
    public static let topTrailing: UnitPoint = UnitPoint(x: 1, y: 0)
    public static let leading: UnitPoint = UnitPoint(x: 0, y: 0.5)
    public static let trailing: UnitPoint = UnitPoint(x: 1, y: 0.5)
    public static let bottomLeading: UnitPoint = UnitPoint(x: 0, y: 1)
    public static let bottom: UnitPoint = UnitPoint(x: 0.5, y: 1)
    public static let bottomTrailing: UnitPoint = UnitPoint(x: 1, y: 1)

    internal var isCenter: Bool {
        x == 0.5 && y == 0.5
    }

    internal var cssXPercent: Float {
        x * 100 - 50
    }

    internal var cssYPercent: Float {
        y * 100 - 50
    }
}

struct CSSTransform: CSSPropertyValue {
    static var styleKey: String = "transform"

    enum AnyFunction {
        case rotation(Rotation)
        case translation(Translation)
        case scale(Scale)
    }

    var value: [AnyFunction]

    static var none: CSSTransform {
        CSSTransform()
    }

    private init() {
        self.value = []
    }

    init(_ value: AnyFunction) {
        self.value = [value]
    }

    var cssString: String {
        guard !value.isEmpty else { return "none" }
        return value.map { $0.cssString }.joined(separator: " ")
    }

    mutating func combineWith(_ other: consuming CSSTransform) {
        value.append(contentsOf: other.value)
    }
}

extension CSSTransform.AnyFunction {
    var cssString: String {
        switch self {
        case .rotation(let rotation):
            if rotation.anchor.isCenter {
                "rotate(\(rotation.angle.degrees)deg)"
            } else {
                """
                translate(\(rotation.anchor.cssXPercent)%, \(rotation.anchor.cssYPercent)%) rotate(\(rotation.angle.degrees)deg)  translate(\(-rotation.anchor.cssXPercent)%, \(-rotation.anchor.cssYPercent)%)
                """
            }
        case .translation(let translation):
            "translate(\(translation.x)px, \(translation.y)px)"
        case .scale(let scale):
            if scale.anchor.isCenter {
                "scale(\(scale.x), \(scale.y))"
            } else {
                """
                translate(\(scale.anchor.cssXPercent)%, \(scale.anchor.cssYPercent)%) scale(\(scale.x), \(scale.y)) translate(\(-scale.anchor.cssXPercent)%, \(-scale.anchor.cssYPercent)%)
                """
            }
        }
    }
}

extension CSSTransform {
    struct Rotation: CSSAnimatable {
        var angle: Angle
        var anchor: UnitPoint

        init(angle: Angle, anchor: UnitPoint) {
            self.angle = angle
            self.anchor = anchor
        }

        var isIdentity: Bool {
            // TODO: epsilon?
            angle.degrees == 0
        }

        var cssValue: CSSTransform {
            guard !isIdentity else { return .none }
            return CSSTransform(.rotation(self))
        }

        init(_animatableVector animatableVector: AnimatableVector) {
            let simd = SIMD4<Float>(_animatableVector: animatableVector)
            self.angle = Angle(degrees: Double(simd[0]))
            self.anchor = UnitPoint(x: simd[1], y: simd[2])
        }

        var animatableVector: AnimatableVector {
            SIMD4<Float>(Float(angle.degrees), Float(anchor.x), Float(anchor.y), 0).animatableVector
        }
    }
}

extension CSSTransform {
    struct Translation: CSSAnimatable {
        var x: Double
        var y: Double

        init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }

        var cssValue: CSSTransform {
            CSSTransform(.translation(self))
        }

        init(_animatableVector animatableVector: AnimatableVector) {
            let simd = SIMD2<Double>(_animatableVector: animatableVector)
            self.x = simd[0]
            self.y = simd[1]
        }

        var animatableVector: AnimatableVector {
            SIMD2<Double>(x, y).animatableVector
        }
    }
}

extension CSSTransform {
    struct Scale: CSSAnimatable {
        var x: Double
        var y: Double
        var anchor: UnitPoint

        init(x: Double, y: Double, anchor: UnitPoint) {
            self.x = x
            self.y = y
            self.anchor = anchor
        }

        var isIdentity: Bool {
            x == 1 && y == 1
        }

        var cssValue: CSSTransform {
            guard !isIdentity else { return .none }
            return CSSTransform(.scale(self))
        }

        init(_animatableVector animatableVector: AnimatableVector) {
            let simd = SIMD4<Double>(_animatableVector: animatableVector)
            self.x = simd[0]
            self.y = simd[1]
            self.anchor = UnitPoint(x: Float(simd[2]), y: Float(simd[3]))
        }

        var animatableVector: AnimatableVector {
            SIMD4<Double>(x, y, Double(anchor.x), Double(anchor.y)).animatableVector
        }
    }
}

struct CSSOpacity {
    var value: Double

    init(value: Double) {
        self.value = min(max(value, 0), 1)
    }
}

extension CSSOpacity: CSSAnimatable {
    var cssValue: CSSOpacity { self }
    init(_animatableVector animatableVector: AnimatableVector) {
        self.value = Double(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        value.animatableVector
    }
}

extension CSSOpacity: CSSPropertyValue {
    static var styleKey: String = "opacity"

    var cssString: String { "\(value)" }

    mutating func combineWith(_ other: CSSOpacity) {
        value *= other.value
    }
}

struct CSSTranslate {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

extension CSSTranslate: CSSAnimatable {
    var cssValue: CSSTranslate { self }
    init(_animatableVector animatableVector: AnimatableVector) {
        let simd = SIMD2<Double>(_animatableVector: animatableVector)
        self.x = simd[0]
        self.y = simd[1]
    }

    var animatableVector: AnimatableVector {
        SIMD2<Double>(x, y).animatableVector
    }
}

extension CSSTranslate: CSSPropertyValue {
    static var styleKey: String = "translate"

    var cssString: String { "\(x)px \(y)px" }

    mutating func combineWith(_ other: CSSTranslate) {
        x += other.x
        y += other.y
    }
}

struct CSSWidth {
    var value: Double

    init(value: Double) {
        self.value = value
    }
}

extension CSSWidth: CSSAnimatable {
    var cssValue: CSSWidth { self }
    init(_animatableVector animatableVector: AnimatableVector) {
        self.value = Double(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        value.animatableVector
    }
}

extension CSSWidth: CSSPropertyValue {
    static var styleKey: String = "width"

    var cssString: String { "\(value)px" }

    mutating func combineWith(_ other: CSSWidth) {
        value += other.value
    }
}

struct CSSHeight {
    var value: Double

    init(value: Double) {
        self.value = value
    }
}

extension CSSHeight: CSSAnimatable {
    var cssValue: CSSHeight { self }
    init(_animatableVector animatableVector: AnimatableVector) {
        self.value = Double(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        value.animatableVector
    }
}

extension CSSHeight: CSSPropertyValue {
    static var styleKey: String = "height"

    var cssString: String { "\(value)px" }

    mutating func combineWith(_ other: CSSHeight) {
        value += other.value
    }
}
