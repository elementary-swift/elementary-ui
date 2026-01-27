import Testing

@testable import ElementaryUI

@Suite
struct AnimatedValueTests {
    @Test
    func progressesAnimation() {
        var value = AnimatedValue(value: TestValue(0))
        value.animate(to: 10, startTime: 0, animation: .linear(duration: 1))
        #expect(value.presentation == 0)
        value.progressToTime(0.2)
        #expect(value.presentation == 2)
        value.progressToTime(0.4)
        #expect(value.presentation == 4)
        value.progressToTime(0.6)
        #expect(value.presentation == 6)
        value.progressToTime(0.8)
        #expect(value.presentation == 8)
        value.progressToTime(1.0)
        #expect(value.presentation == 10)
        value.progressToTime(1.2)
        #expect(value.isAnimating == false)
        #expect(value.presentation == 10)
        value.progressToTime(1.4)
        #expect(value.presentation == 10)
    }

    @Test
    func delaysAnimation() {
        var value = AnimatedValue(value: TestValue(0))
        value.animate(to: 10, startTime: 0, animation: .linear(duration: 1).delay(0.5))
        #expect(value.progressToEnd(sampling: 0.2) == [0, 0, 0, 1, 3, 5, 7, 9, 10])
    }

    @Test
    func speedsUpAnimation() {
        var value = AnimatedValue(value: TestValue(0))
        value.animate(to: 10, startTime: 0, animation: .linear(duration: 1).speed(2))
        #expect(value.progressToEnd(sampling: 0.2) == [0, 4, 8, 10])
    }

    @Test
    func combinesDelaysAndSpeeds() {
        var value = AnimatedValue(value: TestValue(0))
        value.animate(to: 10, startTime: 0, animation: .linear(duration: 2).speed(2).delay(0.5))
        #expect(value.progressToEnd(sampling: 0.2) == [0, 0, 0, 1, 3, 5, 7, 9, 10])
        value.animate(to: 0, startTime: 0, animation: .linear(duration: 0.5).delay(0.5).speed(0.5))
        #expect(value.progressToEnd(sampling: 0.2) == [10, 10, 10, 10, 10, 10, 8, 6, 4, 2, 0, 0])
    }

    @Test
    func peeksChunkOfNextValues() {
        var value = AnimatedValue(value: TestValue(0))
        value.animate(to: 10, startTime: 0, animation: .linear(duration: 1))
        let peeked = value.peekFutureValuesUnlessCompletedOrFinished(stride(from: 0.0, through: 0.7, by: 0.2))
        let peekedAgain = value.peekFutureValuesUnlessCompletedOrFinished(stride(from: 0.2, through: 0.7, by: 0.2))
        let peekedEvenMore = value.peekFutureValuesUnlessCompletedOrFinished(stride(from: 0.9, through: 1.4, by: 0.2))

        #expect(peeked == [0, 2, 4, 6])
        #expect(peekedAgain == [2, 4, 6])
        #expect(peekedEvenMore == [9, 10])
        #expect(value.presentation == 0)
        #expect(value.isAnimating == true)
    }

    @Test
    func triggersCompletions() {
        var value = AnimatedValue(value: TestValue(0))
        let testTracker = TestTracker()

        value.animate(to: 10, startTime: 0, animation: .linear(duration: 1), tracker: testTracker.tracker)

        value.progressToTime(1.0)
        #expect(testTracker.logicallyCompleteCount == 0)
        #expect(testTracker.removedCount == 0)

        value.progressToTime(1.1)
        #expect(testTracker.logicallyCompleteCount == 1)
        #expect(testTracker.removedCount == 1)
    }

    @Test
    func triggersLogicallyCompleteBeforeRemoval() {
        var value = AnimatedValue(value: TestValue(0))
        let testTracker = TestTracker()

        value.animate(to: 10, startTime: 0, animation: .bouncy(duration: 0.5), tracker: testTracker.tracker)

        value.progressToTime(0.4)
        #expect(testTracker.logicallyCompleteCount == 0)
        #expect(testTracker.removedCount == 0)

        value.progressToTime(0.7)
        #expect(testTracker.logicallyCompleteCount == 1)
        #expect(testTracker.removedCount == 0)

        value.progressToTime(1.5)
        #expect(testTracker.logicallyCompleteCount == 1)
        #expect(testTracker.removedCount == 1)
    }

    @Test
    func removesAnimationWhenMerged() {
        var value = AnimatedValue(value: TestValue(0))
        let tracker1 = TestTracker()
        let tracker2 = TestTracker()

        value.animate(to: 10, startTime: 0, animation: .smooth, tracker: tracker1.tracker)
        value.animate(to: 10, startTime: 0.1, animation: .smooth, tracker: tracker2.tracker)

        #expect(tracker1.logicallyCompleteCount == 1)
        #expect(tracker1.removedCount == 1)
        #expect(tracker2.logicallyCompleteCount == 0)
        #expect(tracker2.removedCount == 0)
    }

    @Test
    func removesAllAnimationsWhenUpdated() {
        var value = AnimatedValue(value: TestValue(0))
        let tracker1 = TestTracker()
        let tracker2 = TestTracker()

        value.animate(to: 10, startTime: 0, animation: .linear, tracker: tracker1.tracker)
        value.animate(to: 10, startTime: 0.1, animation: .linear, tracker: tracker2.tracker)

        value.setValue(TestValue(10))

        #expect(tracker1.logicallyCompleteCount == 1)
        #expect(tracker1.removedCount == 1)
        #expect(tracker2.logicallyCompleteCount == 1)
        #expect(tracker2.removedCount == 1)
    }

    @Test
    func removesAllAnimationsWhenCanceled() {
        var value = AnimatedValue(value: TestValue(0))
        let tracker1 = TestTracker()
        let tracker2 = TestTracker()

        value.animate(to: 10, startTime: 0, animation: .linear, tracker: tracker1.tracker)
        value.animate(to: 10, startTime: 0.1, animation: .linear, tracker: tracker2.tracker)

        value.cancelAnimation()

        #expect(value.isAnimating == false)
        #expect(tracker1.logicallyCompleteCount == 1)
        #expect(tracker1.removedCount == 1)
        #expect(tracker2.logicallyCompleteCount == 1)
        #expect(tracker2.removedCount == 1)
    }

    @Test
    func scheudlesACallbackForLogicallyCompletingWhenPeeking() {
        var value = AnimatedValue(value: TestValue(0))
        value.animate(to: 10, startTime: 0, animation: .smooth(duration: 0.5))
        let peeked = value.peekFutureValuesUnlessCompletedOrFinished(stride(from: 0.0, through: 1.5, by: 0.1))
        #expect(peeked == [0, 3, 7, 8, 9, 9, 9])
    }

    @Test
    func peekDoesNotMutateOrTriggerCallbacks() {
        var value = AnimatedValue(value: TestValue(0))
        let tracker = TestTracker()

        value.animate(to: 10, startTime: 0, animation: .linear(duration: 1), tracker: tracker.tracker)

        let beforePresentation = value.presentation
        let beforeAnimating = value.isAnimating
        _ = value.peekFutureValuesUnlessCompletedOrFinished(stride(from: 0.0, through: 1.0, by: 0.1))

        #expect(value.presentation == beforePresentation)
        #expect(value.isAnimating == beforeAnimating)
        #expect(tracker.logicallyCompleteCount == 0)
        #expect(tracker.removedCount == 0)
    }

    @Test
    func mergeReportsCompletionBeforeRemovalForInterruptedAnimation() {
        var value = AnimatedValue(value: TestValue(0))
        var events: [String] = []

        let tracker1 = AnimationTracker()
        tracker1.addAnimationCompletion(criteria: .logicallyComplete) { events.append("C1") }
        tracker1.addAnimationCompletion(criteria: .removed) { events.append("R1") }

        let tracker2 = AnimationTracker()

        value.animate(to: 10, startTime: 0.0, animation: .smooth, tracker: tracker1)
        value.animate(to: 20, startTime: 0.1, animation: .smooth, tracker: tracker2)

        #expect(events == ["C1", "R1"])
    }

    @Test
    func springVelocityIsNonZeroAndChanges() {
        var value = AnimatedValue(value: 0.0 as Double)
        value.animate(to: 10.0, startTime: 0.0, animation: .smooth)

        let v1 = value.getVelocity(at: 0.1)
        let v2 = value.getVelocity(at: 0.2)

        #expect(v1 != nil)
        #expect(v2 != nil)
        #expect(v1 != v2)
        #expect(v1!.magnitude > 0)
    }

    @Test
    func initialVelocityChangesSpringValues() {
        var valueWithoutVelocity = AnimatedValue(value: 0.0 as Double)
        var valueWithVelocity = AnimatedValue(value: 0.0 as Double)

        valueWithoutVelocity.animate(to: 10.0, startTime: 0.0, animation: .smooth)
        valueWithVelocity.animate(
            to: 10.0,
            startTime: 0.0,
            animation: .smooth,
            initialVelocity: 5.0.animatableVector
        )

        valueWithoutVelocity.progressToTime(0.1)
        valueWithVelocity.progressToTime(0.1)

        #expect(valueWithoutVelocity.presentation != valueWithVelocity.presentation)
    }
}

extension AnimatedValue {
    mutating func progressToEnd(sampling: Double) -> [Value] {
        var time = 0.0
        var values: [Value] = []
        values.append(presentation)

        while isAnimating {
            time += sampling
            self.progressToTime(time)
            values.append(presentation)
        }

        return values
    }
}

struct TestValue: AnimatableVectorConvertible, ExpressibleByIntegerLiteral {
    var value: Int

    init(_ value: Int) {
        self.value = value
    }

    init(integerLiteral value: Int) {
        self.value = value
    }

    var animatableVector: AnimatableVector {
        Float(value).animatableVector
    }

    init(_animatableVector animatableVector: AnimatableVector) {
        self.value = Int(Float(_animatableVector: animatableVector))
    }
}

extension TestValue: Equatable, CustomStringConvertible {
    static func == (lhs: TestValue, rhs: TestValue) -> Bool {
        lhs.value == rhs.value
    }

    var description: String {
        value.description
    }
}

private final class TestTracker {
    let tracker = AnimationTracker()
    var logicallyCompleteCount = 0
    var removedCount = 0

    init() {
        tracker.addAnimationCompletion(criteria: .logicallyComplete) {
            self.logicallyCompleteCount += 1
        }
        tracker.addAnimationCompletion(criteria: .removed) {
            self.removedCount += 1
        }
    }
}
