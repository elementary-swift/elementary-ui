final class TransformModifier: DOMElementModifier {
    typealias Value = CSSTransform.AnyFunction

    let upstream: TransformModifier?
    let layerNumber: Int

    var value: CSSTransform.AnyFunction.ValueSource

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, ctx: inout _MountContext) {
        self.value = value.makeSource()
        self.upstream = upstream[TransformModifier.key]
        self.layerNumber = (self.upstream?.layerNumber ?? 0) + 1
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        switch (self.value, value) {
        case (.rotation(let rotation), .rotation(let newRotation)):
            rotation.updateValue(newRotation, &context)
        case (.translation(let translation), .translation(let newTranslation)):
            translation.updateValue(newTranslation, &context)
        case (.scale(let scale), .scale(let newScale)):
            scale.updateValue(newScale, &context)
        default:
            assertionFailure("Cannot update value of different type")
        }
    }

    func mount(_ node: DOM.Node, _ context: inout _MountContext) {
        let modifier = MountedStyleModifier(node, makeLayers(&context), &context)
        context.registerUnmount(modifier)
    }

    private func makeLayers(_ context: inout _MountContext) -> [AnyCSSAnimatedValueInstance<CSSTransform>] {
        if var layers = upstream.map({ $0.makeLayers(&context) }) {
            layers.append(AnyCSSAnimatedValueInstance(value.makeInstance(&context)))
            return layers
        } else {
            return [AnyCSSAnimatedValueInstance(value.makeInstance(&context))]
        }
    }
}

extension CSSTransform.AnyFunction {
    enum ValueSource {
        case rotation(CSSValueSource<CSSTransform.Rotation>)
        case translation(CSSValueSource<CSSTransform.Translation>)
        case scale(CSSValueSource<CSSTransform.Scale>)

        func makeInstance(_ context: inout _MountContext) -> AnyCSSAnimatedValueInstance<CSSTransform> {
            switch self {
            case .rotation(let value):
                AnyCSSAnimatedValueInstance(value.makeInstance(&context))
            case .translation(let value):
                AnyCSSAnimatedValueInstance(value.makeInstance(&context))
            case .scale(let value):
                AnyCSSAnimatedValueInstance(value.makeInstance(&context))
            }
        }
    }

    func makeSource() -> ValueSource {
        switch self {
        case .rotation(let value):
            .rotation(CSSValueSource(value: value))
        case .translation(let value):
            .translation(CSSValueSource(value: value))
        case .scale(let value):
            .scale(CSSValueSource(value: value))
        }
    }
}
