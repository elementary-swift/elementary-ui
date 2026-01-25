protocol CSSAnimatable: AnimatableVectorConvertible {
    associatedtype CSSValue: CSSPropertyValue
    var cssValue: CSSValue { get }
}

protocol CSSPropertyValue {
    static var styleKey: String { get }
    var cssString: String { get }
    mutating func combineWith(_ other: Self)
}

struct SampledAnimationTrack<Value> {
    var startTime: Double
    var duration: Double
    var sampledFrames: [Value]
}

enum CSSAnimatedValue<CSSValue: CSSPropertyValue> {
    case single(CSSValue)
    case animated(SampledAnimationTrack<CSSValue>)

    var singleValue: CSSValue? {
        switch self {
        case .single(let value):
            value
        case .animated(_):
            nil
        }
    }
}

extension DOM.Animation.KeyframeEffect {
    init<CSSValue: CSSPropertyValue>(_ value: CSSAnimatedValue<CSSValue>, isFirst: Bool) {
        self.property = CSSValue.styleKey
        self.composite = isFirst ? .replace : .add

        switch value {
        case .single(let value):
            self.values = [value.cssString]
            self.duration = 0
        case .animated(let track):
            self.values = track.sampledFrames.map { $0.cssString }
            self.duration = Int(track.duration * 1000)
        }
    }
}

final class CSSValueSource<Value: CSSAnimatable & Equatable> {
    var dependencies: DependencyTracker = .init()
    var value: Value

    init(value: consuming Value) {
        self.value = value
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        guard value != self.value else { return }
        self.value = value
        dependencies.invalidateAll(&context)
    }

    func makeInstance() -> Instance {
        Instance(source: self)
    }

    final class Instance: Invalidateable, CSSAnimatedValueInstance {
        let source: CSSValueSource<Value>
        private var animatedValue: AnimatedValue<Value>
        var isDirty: Bool = false
        var target: AnyInvalidateable?

        var value: CSSAnimatedValue<Value.CSSValue>

        init(source: CSSValueSource<Value>) {
            self.source = source
            self.animatedValue = AnimatedValue(value: source.value)
            self.value = .single(animatedValue.presentation.cssValue)

            source.dependencies.addDependency(self)
        }

        func setTarget(_ target: AnyInvalidateable) {
            precondition(self.target == nil, "target already set")
            self.target = target
        }

        func invalidate(_ context: inout _TransactionContext) {
            _ = animatedValue.setValueAndReturnIfAnimationWasStarted(
                source.value,
                transaction: context.transaction,
                frameTime: context.currentFrameTime
            )
            updateValue(&context)
        }

        func progressAnimation(_ context: inout _TransactionContext) {
            animatedValue.progressToTime(context.currentFrameTime)

            updateValue(&context)
        }

        func unmount(_ context: inout _CommitContext) {
            animatedValue.cancelAnimation()
            source.dependencies.removeDependency(self)
        }

        private func updateValue(_ context: inout _TransactionContext) {
            value = animatedValue.nextCSSAnimationValue(frameTime: context.currentFrameTime)
            isDirty = true
            target?.invalidate(&context)
        }
    }
}

protocol CSSAnimatedValueInstance<CSSValue> {
    associatedtype CSSValue: CSSPropertyValue
    var value: CSSAnimatedValue<CSSValue> { get }
    var isDirty: Bool { get nonmutating set }
    func setTarget(_ target: AnyInvalidateable)
    func unmount(_ context: inout _CommitContext)
    func progressAnimation(_ context: inout _TransactionContext)
}

struct AnyCSSAnimatedValueInstance<CSSProperty: CSSPropertyValue>: CSSAnimatedValueInstance {
    let _progressAnimation: (inout _TransactionContext) -> Void
    let _getValue: () -> CSSAnimatedValue<CSSProperty>
    let _getIsDirty: () -> Bool
    let _setIsDirty: (Bool) -> Void
    let _setTarget: (AnyInvalidateable) -> Void
    let _unmount: (inout _CommitContext) -> Void

    init<Instance: CSSAnimatedValueInstance>(_ value: Instance) where Instance.CSSValue == CSSProperty {
        self._progressAnimation = value.progressAnimation(_:)
        self._getValue = { value.value }
        self._getIsDirty = { value.isDirty }
        self._setIsDirty = { value.isDirty = $0 }
        self._setTarget = { value.setTarget($0) }
        self._unmount = { value.unmount(&$0) }
    }

    func progressAnimation(_ context: inout _TransactionContext) {
        _progressAnimation(&context)
    }

    var value: CSSAnimatedValue<CSSProperty> {
        _getValue()
    }

    var isDirty: Bool {
        get {
            _getIsDirty()
        }
        nonmutating set {
            _setIsDirty(newValue)
        }
    }

    func setTarget(_ target: AnyInvalidateable) {
        _setTarget(target)
    }

    func unmount(_ context: inout _CommitContext) {
        _unmount(&context)
    }
}

extension AnimatedValue where Value: CSSAnimatable {
    func nextCSSAnimationValue(
        frameTime: Double,
        sampleInterval: Double = 1.0 / 40.0,
        maxDuration: Double = 1.5
    ) -> CSSAnimatedValue<Value.CSSValue> {
        if self.isAnimating {
            let frames = peekFutureValuesUnlessCompletedOrFinished(
                stride(from: frameTime, through: frameTime + maxDuration, by: sampleInterval)
            )
            return .animated(
                SampledAnimationTrack(
                    startTime: frameTime,
                    duration: sampleInterval * Double(frames.count - 1),
                    sampledFrames: frames.map { $0.cssValue }
                )
            )
        }
        return .single(presentation.cssValue)
    }
}
