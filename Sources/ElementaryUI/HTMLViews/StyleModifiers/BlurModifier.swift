struct CSSBlur: Equatable {
    var radius: Double

    init(radius: Double) {
        self.radius = max(0, radius)
    }
}

extension CSSBlur: CSSAnimatable {
    var cssValue: CSSBlur { self }

    init(_animatableVector animatableVector: AnimatableVector) {
        self.radius = Double(_animatableVector: animatableVector)
    }

    var animatableVector: AnimatableVector {
        radius.animatableVector
    }
}

extension CSSBlur: CSSPropertyValue {
    static var styleKey: String = "filter"

    var cssString: String {
        let clampedRadius = max(0, radius)
        if clampedRadius > 0 {
            return "blur(\(clampedRadius)px)"
        } else {
            return "none"
        }
    }

    mutating func combineWith(_ other: CSSBlur) {
        radius += other.radius
    }
}

final class BlurModifier: DOMElementModifier {
    typealias Value = CSSBlur

    let upstream: BlurModifier?
    let layerNumber: Int

    var value: CSSValueSource<CSSBlur>

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.value = CSSValueSource(value: value)
        self.upstream = upstream[BlurModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        self.value.updateValue(value, &context)
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        AnyUnmountable(MountedStyleModifier(node, makeLayers(&context), &context))
    }

    private func makeLayers(_ context: inout _CommitContext) -> [CSSValueSource<CSSBlur>.Instance] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(value.makeInstance())
            return layers
        } else {
            return [value.makeInstance()]
        }
    }
}
