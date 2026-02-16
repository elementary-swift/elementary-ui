struct CSSBorderWidth: Equatable {
    var value: Double

    init(value: Double) {
        self.value = max(0, value)
    }
}

extension CSSBorderWidth: CSSAnimatable {
    var cssValue: CSSBorderWidth { self }

    init(_animatableVector animatableVector: AnimatableVector) {
        self.value = Double(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        value.animatableVector
    }
}

extension CSSBorderWidth: CSSPropertyValue {
    static var styleKey: String = "border-width"

    var cssString: String {
        "\(max(0, value))px"
    }

    mutating func combineWith(_ other: CSSBorderWidth) {
        value += other.value
    }
}

struct CSSBorderColor: Equatable {
    var color: CSSColor

    init(color: CSSColor) {
        self.color = color
    }
}

extension CSSBorderColor: CSSAnimatable {
    var cssValue: CSSBorderColor { self }

    init(_animatableVector animatableVector: AnimatableVector) {
        self.color = CSSColor(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        color.animatableVector
    }
}

extension CSSBorderColor: CSSPropertyValue {
    static var styleKey: String = "border-color"

    var cssString: String {
        let r = Int(max(0, min(255, color.red)).rounded())
        let g = Int(max(0, min(255, color.green)).rounded())
        let b = Int(max(0, min(255, color.blue)).rounded())
        let a = max(0, min(1, color.alpha))
        return "rgba(\(r), \(g), \(b), \(a))"
    }

    mutating func combineWith(_ other: CSSBorderColor) {
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

struct CSSCornerRadius: Equatable {
    var value: Double

    init(value: Double) {
        self.value = max(0, value)
    }
}

extension CSSCornerRadius: CSSAnimatable {
    var cssValue: CSSCornerRadius { self }

    init(_animatableVector animatableVector: AnimatableVector) {
        self.value = Double(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        value.animatableVector
    }
}

extension CSSCornerRadius: CSSPropertyValue {
    static var styleKey: String = "border-radius"

    var cssString: String {
        "\(max(0, value))px"
    }

    mutating func combineWith(_ other: CSSCornerRadius) {
        value = max(value, other.value)
    }
}

final class BorderWidthModifier: DOMElementModifier {
    typealias Value = CSSBorderWidth

    let upstream: BorderWidthModifier?
    let layerNumber: Int

    var value: CSSValueSource<CSSBorderWidth>

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.value = CSSValueSource(value: value)
        self.upstream = upstream[BorderWidthModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        self.value.updateValue(value, &context)
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        AnyUnmountable(MountedStyleModifier(node, makeLayers(&context), &context))
    }

    private func makeLayers(_ context: inout _CommitContext) -> [CSSValueSource<CSSBorderWidth>.Instance] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(value.makeInstance())
            return layers
        } else {
            return [value.makeInstance()]
        }
    }
}

final class BorderColorModifier: DOMElementModifier {
    typealias Value = CSSBorderColor

    let upstream: BorderColorModifier?
    let layerNumber: Int

    var value: CSSValueSource<CSSBorderColor>

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.value = CSSValueSource(value: value)
        self.upstream = upstream[BorderColorModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        self.value.updateValue(value, &context)
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        AnyUnmountable(MountedStyleModifier(node, makeLayers(&context), &context))
    }

    private func makeLayers(_ context: inout _CommitContext) -> [CSSValueSource<CSSBorderColor>.Instance] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(value.makeInstance())
            return layers
        } else {
            return [value.makeInstance()]
        }
    }
}

final class CornerRadiusModifier: DOMElementModifier {
    typealias Value = CSSCornerRadius

    let upstream: CornerRadiusModifier?
    let layerNumber: Int

    var value: CSSValueSource<CSSCornerRadius>

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.value = CSSValueSource(value: value)
        self.upstream = upstream[CornerRadiusModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        self.value.updateValue(value, &context)
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        AnyUnmountable(MountedStyleModifier(node, makeLayers(&context), &context))
    }

    private func makeLayers(_ context: inout _CommitContext) -> [CSSValueSource<CSSCornerRadius>.Instance] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(value.makeInstance())
            return layers
        } else {
            return [value.makeInstance()]
        }
    }
}
