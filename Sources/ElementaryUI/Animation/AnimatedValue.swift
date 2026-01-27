private struct RunningAnimation {
    let trackedInstance: AnimationTracker.Instance?
    let animation: Animation
    let startTime: Double
    let target: AnimatableVector
    var context: AnimationContext
    var hasLogicallyCompleted: Bool = false

    mutating func animate(time: Double, additionalVector: AnimatableVector?) -> (AnimatableVector, Bool)? {
        let result: AnimatableVector?

        let before = context.isLogicallyComplete

        if let additionalVector {
            result = animation.animate(value: target + additionalVector, time: time - startTime, context: &context)
        } else {
            result = animation.animate(value: target, time: time - startTime, context: &context)
        }

        return result.map { ($0, !before && context.isLogicallyComplete) }
    }

    mutating func reportRemoved() {
        // TODO: maybe make this non-copyable and have a consuming remove func
        trackedInstance?.reportRemoved()
    }

    mutating func reportLogicallyComplete() {
        trackedInstance?.reportLogicallyComplete()
    }
}

struct AnimatedValue<Value: AnimatableVectorConvertible>: ~Copyable {
    private var runningAnimations: [RunningAnimation] = []
    private var currentTarget: Value
    private var currentAnimationValue: Value

    private var animationBase: AnimatableVector

    var model: Value { borrowing get { currentTarget } }
    var presentation: Value { borrowing get { currentAnimationValue } }
    var isAnimating: Bool { borrowing get { !runningAnimations.isEmpty } }

    init(value: Value) {
        self.animationBase = value.animatableVector
        self.currentTarget = value
        self.currentAnimationValue = value
    }

    mutating func setValue(_ value: Value) {
        self.animationBase = value.animatableVector
        self.currentTarget = value
        self.currentAnimationValue = value
        if !runningAnimations.isEmpty {
            removeAnimations(upThrough: runningAnimations.endIndex - 1, skipBaseUpdate: true)
        }
    }

    mutating func cancelAnimation() {
        guard isAnimating else { return }

        // setting value cancels all animations
        setValue(currentTarget)
    }

    mutating func animate(
        to value: Value,
        startTime: Double,
        animation: Animation,
        tracker: AnimationTracker? = nil,
        initialVelocity: AnimatableVector? = nil
    ) {

        self.progressToTime(startTime)
        var animationTarget = value.animatableVector - currentTarget.animatableVector
        var context = AnimationContext()

        // If initial velocity is provided (e.g., from a canceled animation), use it
        if let initialVelocity {
            context.initialVelocity = initialVelocity
        }

        if let previous = runningAnimations.last {
            var previousContext = previous.context
            let elapsedTime = startTime - previous.startTime
            let shouldMerge = animation.shouldMerge(
                previous: previous.animation,
                value: previous.target,
                time: elapsedTime,
                context: &previousContext
            )

            if shouldMerge {
                self.animationBase = currentAnimationValue.animatableVector
                self.removeAnimations(upThrough: runningAnimations.endIndex - 1, skipBaseUpdate: true)
                animationTarget = value.animatableVector - self.animationBase
                context = previousContext
                // FIXME: this feels very hacky....
                context.isLogicallyComplete = false
            }
        }

        self.currentTarget = value
        runningAnimations.append(
            RunningAnimation(
                trackedInstance: tracker?.addAnimation(),
                animation: animation,
                startTime: startTime,
                target: animationTarget,
                context: context
            )
        )
    }

    /// Returns the current velocity of the animation, if animating.
    func getVelocity(at time: Double) -> AnimatableVector? {
        guard let last = runningAnimations.last else { return nil }
        let elapsedTime = time - last.startTime
        return last.animation.velocity(value: last.target, time: elapsedTime, context: last.context)
    }

    mutating func progressToTime(_ time: Double) {
        guard isAnimating else { return }

        let (animatedVector, completedIndexes, finishedAnimationIndex) = calculateAnimationAtTime(
            time,
            runningAnimations: &runningAnimations[...],
        )

        // Report logical completion for any animations that became logically complete at this time.
        // This must happen here (mutating path), not inside calculateAnimationAtTime, so peeking stays non-mutating.
        for index in completedIndexes {
            runningAnimations[index].reportLogicallyComplete()
        }

        if let finishedAnimationIndex {
            removeAnimations(upThrough: finishedAnimationIndex)
        }

        if isAnimating {
            self.currentAnimationValue = Value(_animatableVector: animationBase + animatedVector)
        } else {
            // NOTE: avoid floating point weirdness
            self.currentAnimationValue = self.currentTarget
            self.animationBase = self.currentTarget.animatableVector
        }
    }

    // TODO: this can't be the best shape of this function...
    func peekFutureValuesUnlessCompletedOrFinished(_ times: StrideThrough<Double>) -> [Value] {
        var results: [Value] = []
        var runningAnimations = runningAnimations[...]
        var base = animationBase

        results.reserveCapacity(times.underestimatedCount)

        for time in times {
            var shouldBailEarly = false

            let (animatedVector, completedIndexes, removedUpToIndex) = calculateAnimationAtTime(
                time,
                runningAnimations: &runningAnimations,
            )

            if !completedIndexes.isEmpty {
                shouldBailEarly = true
            }

            if let removedUpToIndex {
                for i in runningAnimations.startIndex...removedUpToIndex {
                    base += runningAnimations[i].target
                }
                runningAnimations = runningAnimations[(removedUpToIndex + 1)...]
                shouldBailEarly = true
            }

            if runningAnimations.isEmpty {
                results.append(self.currentTarget)
                shouldBailEarly = true
            } else {
                results.append(Value(_animatableVector: base + animatedVector))
            }

            if shouldBailEarly {
                break
            }
        }
        return results
    }

    private mutating func removeAnimations(upThrough index: Int, skipBaseUpdate: Bool = false) {
        for i in 0...index {
            // NOTE: completion is triggered automatically on removal, no extra handling needed here
            runningAnimations[i].reportRemoved()
            if !skipBaseUpdate {
                self.animationBase += runningAnimations[i].target
            }
        }
        runningAnimations.removeSubrange(0...index)
    }
}

private func calculateAnimationAtTime(
    _ time: Double,
    runningAnimations: inout ArraySlice<RunningAnimation>
) -> (animatedVector: AnimatableVector, completedIndexes: [Int], finishedAnimationIndex: Int?) {
    guard runningAnimations.count > 1 else {
        assert(runningAnimations.first != nil, "Running animations should not be empty")
        let index = runningAnimations.startIndex
        if let (vector, logicallyCompleted) = runningAnimations[index].animate(time: time, additionalVector: nil) {
            return (vector, logicallyCompleted ? [index] : [], nil)
        } else {
            return (runningAnimations[0].target, [], index)
        }
    }

    var finishedAnimationIndex: Int?
    var completedIndexes: [Int] = []
    var index = runningAnimations.startIndex

    let zero = AnimatableVector.zero(runningAnimations.first!.target)

    var totalAnimationVector = zero
    var carryOverVector = zero

    while index < runningAnimations.endIndex {
        if let (vector, logicallyCompleted) = runningAnimations[index].animate(time: time, additionalVector: carryOverVector) {
            totalAnimationVector += vector
            carryOverVector = runningAnimations[index].target - vector
            if logicallyCompleted {
                completedIndexes.append(index)
            }
        } else {
            finishedAnimationIndex = index
            //totalAnimationVector = zero
            carryOverVector = zero
        }

        runningAnimations.formIndex(after: &index)
    }

    return (totalAnimationVector, completedIndexes, finishedAnimationIndex)
}

internal extension AnimatedValue {
    mutating func setValueAndReturnIfAnimationWasStarted(
        _ value: Value,
        transaction: borrowing Transaction,
        frameTime: Double,
        initialVelocity: AnimatableVector? = nil
    ) -> Bool {
        guard value != currentTarget else { return false }

        let wasAnimating = isAnimating

        // TODO: really think about disablesAnimation flag and what it means - we need this at least for FLIP for now
        //!transaction.disablesAnimation,
        if let animation = transaction.animation {
            self.animate(
                to: value,
                startTime: frameTime,
                animation: animation,
                tracker: transaction._animationTracker,
                initialVelocity: initialVelocity
            )
        } else {
            self.setValue(value)
        }

        return isAnimating && !wasAnimating
    }
}
