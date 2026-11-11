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

final class CSSValueSource<Value: CSSAnimatable & Equatable>: DependencyNode {
    var value: Value

    init(value: consuming Value) {
        self.value = value
        super.init()
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        guard value != self.value else { return }
        self.value = value
        dependents.invalidateAll(&context)
    }

    /// An instance that follows this source until the enclosing slot is dropped.
    func makeInstance(_ context: inout _MountContext) -> Instance {
        let instance = Instance(source: self)
        context.follow(self, with: instance)
        return instance
    }

    /// Followed by the mounted modifier that combines its value.
    final class Instance: DependencyNode, CSSAnimatedValueInstance {
        let source: CSSValueSource<Value>
        private var animatedValue: AnimatedValue<Value>
        var isDirty: Bool = false

        var value: CSSAnimatedValue<Value.CSSValue>

        init(source: CSSValueSource<Value>) {
            self.source = source
            self.animatedValue = AnimatedValue(value: source.value)
            self.value = .single(animatedValue.presentation.cssValue)
            super.init()
        }

        var dependencySource: DependencyNode { self }

        override func invalidate(_ context: inout _TransactionContext) {
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
        }

        private func updateValue(_ context: inout _TransactionContext) {
            value = animatedValue.nextCSSAnimationValue(frameTime: context.currentFrameTime)
            isDirty = true
            dependents.invalidateAll(&context)
        }
    }
}

protocol CSSAnimatedValueInstance<CSSValue> {
    associatedtype CSSValue: CSSPropertyValue
    var value: CSSAnimatedValue<CSSValue> { get }
    var isDirty: Bool { get nonmutating set }
    /// What a mounted modifier follows to learn that `value` changed.
    var dependencySource: DependencyNode { get }
    func unmount(_ context: inout _CommitContext)
    func progressAnimation(_ context: inout _TransactionContext)
}

struct AnyCSSAnimatedValueInstance<CSSProperty: CSSPropertyValue>: CSSAnimatedValueInstance {
    let _progressAnimation: (inout _TransactionContext) -> Void
    let _getValue: () -> CSSAnimatedValue<CSSProperty>
    let _getIsDirty: () -> Bool
    let _setIsDirty: (Bool) -> Void
    let dependencySource: DependencyNode
    let _unmount: (inout _CommitContext) -> Void

    init<Instance: CSSAnimatedValueInstance>(_ value: Instance) where Instance.CSSValue == CSSProperty {
        self._progressAnimation = value.progressAnimation(_:)
        self._getValue = { value.value }
        self._getIsDirty = { value.isDirty }
        self._setIsDirty = { value.isDirty = $0 }
        self.dependencySource = value.dependencySource
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
