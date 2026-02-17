final class FilterModifier: DOMElementModifier {
    typealias Value = CSSFilter.AnyFunction

    let upstream: FilterModifier?
    let layerNumber: Int

    var value: CSSFilter.AnyFunction.ValueSource

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.value = value.makeSource()
        self.upstream = upstream[FilterModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        switch (self.value, value) {
        case (.blur(let blur), .blur(let newBlur)):
            blur.updateValue(newBlur, &context)
        case (.saturation(let saturation), .saturation(let newSaturation)):
            saturation.updateValue(newSaturation, &context)
        case (.brightness(let brightness), .brightness(let newBrightness)):
            brightness.updateValue(newBrightness, &context)
        default:
            assertionFailure("Cannot update value of different type")
        }
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        AnyUnmountable(MountedStyleModifier(node, makeLayers(&context), &context))
    }

    private func makeLayers(_ context: inout _CommitContext) -> [AnyCSSAnimatedValueInstance<CSSFilter>] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(AnyCSSAnimatedValueInstance(value.makeInstance()))
            return layers
        } else {
            return [AnyCSSAnimatedValueInstance(value.makeInstance())]
        }
    }
}

extension CSSFilter.AnyFunction {
    enum ValueSource {
        case blur(CSSValueSource<CSSFilter.Blur>)
        case saturation(CSSValueSource<CSSFilter.Saturation>)
        case brightness(CSSValueSource<CSSFilter.Brightness>)

        func makeInstance() -> AnyCSSAnimatedValueInstance<CSSFilter> {
            switch self {
            case .blur(let value):
                AnyCSSAnimatedValueInstance(value.makeInstance())
            case .saturation(let value):
                AnyCSSAnimatedValueInstance(value.makeInstance())
            case .brightness(let value):
                AnyCSSAnimatedValueInstance(value.makeInstance())
            }
        }
    }

    func makeSource() -> ValueSource {
        switch self {
        case .blur(let value):
            .blur(CSSValueSource(value: value))
        case .saturation(let value):
            .saturation(CSSValueSource(value: value))
        case .brightness(let value):
            .brightness(CSSValueSource(value: value))
        }
    }
}
