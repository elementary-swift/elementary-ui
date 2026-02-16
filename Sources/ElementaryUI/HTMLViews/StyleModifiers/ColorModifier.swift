/// A color value that can be used for styling views.
///
/// Use `CSSColor` to specify colors for view modifiers like ``View/backgroundColor(_:)``
/// and ``View/foregroundColor(_:)``.
///
/// ## Creating Colors
///
/// ```swift
/// // RGB colors (0-255 range)
/// let red = CSSColor.rgb(255, 0, 0)
/// let green = CSSColor.rgb(0, 255, 0)
///
/// // RGBA colors with alpha (0-1 range)
/// let semiTransparent = CSSColor.rgba(255, 0, 0, 0.5)
///
/// // Using the initializer
/// let custom = CSSColor(red: 128, green: 64, blue: 255, alpha: 0.8)
/// ```
public struct CSSColor: Equatable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static func rgb(_ red: Float, _ green: Float, _ blue: Float) -> CSSColor {
        CSSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    public static func rgba(_ red: Float, _ green: Float, _ blue: Float, _ alpha: Float) -> CSSColor {
        CSSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension CSSColor: AnimatableVectorConvertible {
    public init(_animatableVector animatableVector: AnimatableVector) {
        let simd = SIMD4<Float>(_animatableVector: animatableVector)
        self.red = simd[0]
        self.green = simd[1]
        self.blue = simd[2]
        self.alpha = simd[3]
    }

    public var animatableVector: AnimatableVector {
        SIMD4<Float>(red, green, blue, alpha).animatableVector
    }
}

struct CSSBackgroundColor: Equatable {
    var color: CSSColor

    init(color: CSSColor) {
        self.color = color
    }
}

extension CSSBackgroundColor: CSSAnimatable {
    var cssValue: CSSBackgroundColor { self }

    init(_animatableVector animatableVector: AnimatableVector) {
        self.color = CSSColor(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        color.animatableVector
    }
}

extension CSSBackgroundColor: CSSPropertyValue {
    static var styleKey: String = "background-color"

    var cssString: String {
        let r = Int(max(0, min(255, color.red)).rounded())
        let g = Int(max(0, min(255, color.green)).rounded())
        let b = Int(max(0, min(255, color.blue)).rounded())
        let a = max(0, min(1, color.alpha))
        return "rgba(\(r), \(g), \(b), \(a))"
    }

    mutating func combineWith(_ other: CSSBackgroundColor) {
        let topAlpha = other.color.alpha
        let bottomAlpha = color.alpha * (1 - topAlpha)
        let newAlpha = topAlpha + bottomAlpha

        if newAlpha > 0 {
            color.red = (other.color.red * topAlpha + color.red * bottomAlpha) / newAlpha
            color.green = (other.color.green * topAlpha + color.green * bottomAlpha) / newAlpha
            color.blue = (other.color.blue * topAlpha + color.blue * bottomAlpha) / newAlpha
            color.alpha = newAlpha
        }
    }
}

struct CSSForegroundColor: Equatable {
    var color: CSSColor

    init(color: CSSColor) {
        self.color = color
    }
}

extension CSSForegroundColor: CSSAnimatable {
    var cssValue: CSSForegroundColor { self }

    init(_animatableVector animatableVector: AnimatableVector) {
        self.color = CSSColor(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        color.animatableVector
    }
}

extension CSSForegroundColor: CSSPropertyValue {
    static var styleKey: String = "color"

    var cssString: String {
        let r = Int(max(0, min(255, color.red)).rounded())
        let g = Int(max(0, min(255, color.green)).rounded())
        let b = Int(max(0, min(255, color.blue)).rounded())
        let a = max(0, min(1, color.alpha))
        return "rgba(\(r), \(g), \(b), \(a))"
    }

    mutating func combineWith(_ other: CSSForegroundColor) {
        let topAlpha = other.color.alpha
        let bottomAlpha = color.alpha * (1 - topAlpha)
        let newAlpha = topAlpha + bottomAlpha

        if newAlpha > 0 {
            color.red = (other.color.red * topAlpha + color.red * bottomAlpha) / newAlpha
            color.green = (other.color.green * topAlpha + color.green * bottomAlpha) / newAlpha
            color.blue = (other.color.blue * topAlpha + color.blue * bottomAlpha) / newAlpha
            color.alpha = newAlpha
        }
    }
}

final class BackgroundColorModifier: DOMElementModifier {
    typealias Value = CSSBackgroundColor

    let upstream: BackgroundColorModifier?
    let layerNumber: Int

    var value: CSSValueSource<CSSBackgroundColor>

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.value = CSSValueSource(value: value)
        self.upstream = upstream[BackgroundColorModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        self.value.updateValue(value, &context)
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        AnyUnmountable(MountedStyleModifier(node, makeLayers(&context), &context))
    }

    private func makeLayers(_ context: inout _CommitContext) -> [CSSValueSource<CSSBackgroundColor>.Instance] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(value.makeInstance())
            return layers
        } else {
            return [value.makeInstance()]
        }
    }
}

final class ForegroundColorModifier: DOMElementModifier {
    typealias Value = CSSForegroundColor

    let upstream: ForegroundColorModifier?
    let layerNumber: Int

    var value: CSSValueSource<CSSForegroundColor>

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.value = CSSValueSource(value: value)
        self.upstream = upstream[ForegroundColorModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        self.value.updateValue(value, &context)
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        AnyUnmountable(MountedStyleModifier(node, makeLayers(&context), &context))
    }

    private func makeLayers(_ context: inout _CommitContext) -> [CSSValueSource<CSSForegroundColor>.Instance] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(value.makeInstance())
            return layers
        } else {
            return [value.makeInstance()]
        }
    }
}
