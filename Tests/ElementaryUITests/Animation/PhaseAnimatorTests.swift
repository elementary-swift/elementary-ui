import ElementaryUI
import Reactivity
import Testing

@MainActor
@Suite
struct PhaseAnimatorTests {
    @Test
    func triggeredCycleReturnsToFirstAndWaits() {
        let state = PhaseInputs()
        let dom = TestDOM()
        var targets: [Int] = []
        let app = dom.mount {
            PhaseAnimator([0, 1, 2], trigger: state.trigger) { phase in
                PhaseNumber(value: Double(phase))
            } animation: {
                targets.append($0)
                return .linear(duration: 1)
            }
        }
        dom.flushMicrotasks()
        #expect(targets.isEmpty)
        #expect(dom.ops.contains(.createText("0.0")))
        state.trigger += 1
        dom.flushMicrotasks()
        #expect(targets == [1])
        dom.advanceTime(by: 1.1)
        #expect(targets == [1, 2])
        dom.advanceTime(by: 1.1)
        #expect(targets == [1, 2, 0])
        dom.advanceTime(by: 1.1)
        #expect(targets == [1, 2, 0])
        state.trigger = 1
        dom.flushMicrotasks()
        #expect(targets == [1, 2, 0])
        app.unmount()
    }

    @Test
    func continuousContainerAndModifierWrap() {
        let dom = TestDOM()
        var containerTargets: [Bool] = []
        var modifierTargets: [Bool] = []
        let app = dom.mount {
            div {
                PhaseAnimator([false, true]) { phase in
                    PhaseNumber(value: phase ? 1 : 0)
                } animation: {
                    containerTargets.append($0)
                    return .linear(duration: 1)
                }
                div { "pulse" }.phaseAnimator([false, true]) { content, phase in
                    content.opacity(phase ? 1 : 0.5)
                } animation: {
                    modifierTargets.append($0)
                    return .linear(duration: 1)
                }
            }
        }
        dom.flushMicrotasks()
        #expect(containerTargets == [true])
        #expect(modifierTargets == [true])
        for _ in 0..<3 {
            dom.finishAnimations()
            dom.runNextFrame()
        }
        #expect(containerTargets == [true, false, true, false])
        #expect(modifierTargets == containerTargets)
        app.unmount()
    }

    @Test(arguments: [2, 3, 4])
    func retriggerUsesCurrentTarget(count: Int) {
        for target in 0..<count {
            let state = PhaseInputs()
            let dom = TestDOM()
            var targets: [Int] = []
            let app = dom.mount {
                PhaseAnimator(0..<count, trigger: state.trigger) { phase in
                    PhaseNumber(value: Double(phase))
                } animation: {
                    targets.append($0)
                    return .linear(duration: 1)
                }
            }
            dom.flushMicrotasks()
            state.trigger += 1
            dom.flushMicrotasks()
            let steps = target == 0 ? count - 1 : target - 1
            for _ in 0..<steps { dom.advanceTime(by: 1.1) }
            #expect(targets.last == target)
            dom.advanceTime(by: 0.25)
            state.trigger += 1
            dom.flushMicrotasks()
            let expected = target == 1 ? 2 % count : 1
            #expect(targets.last == expected)
            // Old completion callbacks must not advance the replacement sequence.
            let before = targets.count
            dom.advanceTime(by: 0.8)
            #expect(targets.count == before)
            for _ in 0..<count { dom.advanceTime(by: 1.1) }
            #expect(targets.last == 0)
            let finished = targets.count
            dom.advanceTime(by: 10)
            #expect(targets.count == finished)
            app.unmount()
        }
    }

    @Test(arguments: [true, false])
    func ordinaryCompletionHandlesNilAndUnchangedValues(nilAnimation: Bool) {
        let state = PhaseInputs()
        let dom = TestDOM()
        var targets: [Int] = []
        let app = dom.mount {
            PhaseAnimator([0, 1, 1, 2], trigger: state.trigger) { _ in
                PhaseNumber(value: 0)
            } animation: {
                targets.append($0)
                return nilAnimation ? nil : .linear(duration: 1).delay(5)
            }
        }
        dom.flushMicrotasks()
        state.trigger += 1
        dom.flushMicrotasks()
        #expect(targets == [1, 1, 2, 0])
        #expect(!dom.hasWorkScheduled)
        app.unmount()
    }

    @Test
    func waitsForAllAnimationsAndHonorsDelay() {
        let state = PhaseInputs()
        let dom = TestDOM()
        var targets: [Int] = []
        let app = dom.mount {
            PhaseAnimator([0, 1], trigger: state.trigger) { phase in
                PhaseNumber(value: Double(phase))
                PhaseNumber(value: Double(phase)).animation(.linear(duration: 2), value: phase)
            } animation: {
                targets.append($0)
                return .linear(duration: 0.5).delay(1)
            }
        }
        dom.flushMicrotasks()
        state.trigger += 1
        dom.flushMicrotasks()
        dom.advanceTime(by: 0.75)
        #expect(targets == [1])
        dom.advanceTime(by: 0.85)
        #expect(targets == [1])
        dom.advanceTime(by: 0.5)
        #expect(targets == [1, 0])
        app.unmount()
    }

    @Test
    func springAdvancesBeforeSettling() {
        let state = PhaseInputs()
        let dom = TestDOM()
        var targets: [Int] = []
        let app = dom.mount {
            PhaseAnimator([0, 1], trigger: state.trigger) { phase in
                PhaseNumber(value: Double(phase))
            } animation: {
                targets.append($0)
                return .bouncy(duration: 1)
            }
        }
        dom.flushMicrotasks()
        state.trigger += 1
        dom.flushMicrotasks()
        dom.advanceTime(by: 1.01)
        #expect(targets == [1, 0])
        #expect(dom.hasWorkScheduled)
        app.unmount()
    }

    @Test
    func replacingPhasesResetsAndCanTriggerInSameUpdate() {
        let state = PhaseInputs()
        let dom = TestDOM()
        var targets: [Int] = []
        let app = dom.mount {
            PhaseAnimator(state.phases, trigger: state.trigger) { phase in
                PhaseNumber(value: Double(phase))
            } animation: {
                targets.append($0)
                return .linear(duration: 1)
            }
        }
        dom.flushMicrotasks()
        state.trigger += 1
        dom.flushMicrotasks()
        state.phases = [10, 20]
        dom.flushMicrotasks()
        dom.advanceTime(by: 2)
        #expect(targets == [1])
        #expect(dom.ops.contains(.patchText(node: "0.0", to: "10.0")))
        state.phases = [30, 40]
        state.trigger += 1
        dom.flushMicrotasks()
        #expect(targets == [1, 40])
        app.unmount()
    }

    @Test
    func emptyAndSinglePhasesAreStaticAndCanBecomePopulated() {
        let state = PhaseInputs()
        state.phases = []
        let dom = TestDOM()
        var targets: [Int] = []
        let app = dom.mount {
            PhaseAnimator(state.phases) { phase in
                PhaseNumber(value: Double(phase))
            } animation: {
                targets.append($0)
                return .linear(duration: 1)
            }
        }
        dom.flushMicrotasks()
        #expect(!dom.ops.contains(.createElement("p")))
        state.phases = [7]
        dom.flushMicrotasks()
        #expect(targets.isEmpty)
        #expect(dom.ops.contains(.createText("7.0")))
        state.phases = [3, 4]
        dom.flushMicrotasks()
        #expect(targets == [4])
        state.phases = []
        dom.flushMicrotasks()
        dom.advanceTime(by: 5)
        #expect(targets == [4])
        app.unmount()
    }

    @Test
    func modifierPreservesChildStateAndRefreshesParentContent() {
        let state = PhaseInputs()
        let dom = TestDOM()
        var mounts = 0
        var removals = 0
        var targets: [Int] = []
        let app = dom.mount {
            StatefulPhaseChild(label: state.label)
                .onAppear { mounts += 1 }
                .onDisappear { removals += 1 }
                .phaseAnimator([0, 1], trigger: state.trigger) { content, phase in
                    content.opacity(phase == 0 ? 0.5 : 1)
                } animation: {
                    targets.append($0)
                    return .linear(duration: 1)
                }
        }
        dom.flushMicrotasks()
        state.trigger += 1
        dom.flushMicrotasks()
        state.label = "updated"
        dom.flushMicrotasks()
        for _ in 0..<2 {
            dom.finishAnimations()
            dom.runNextFrame()
        }
        #expect(targets == [1, 0])
        #expect(mounts == 1)
        #expect(removals == 0)
        #expect(dom.ops.contains(.patchText(node: "initial:1", to: "updated:1")))
        app.unmount()
        #expect(removals == 1)
    }

    @Test
    func updatesAnimationClosureAndTracksContentReads() {
        let state = PhaseInputs()
        let dom = TestDOM()
        var selectedDurations: [Double] = []
        let app = dom.mount {
            // Capture a value in the parent to verify that the stored closure is refreshed.
            let duration = state.duration
            return PhaseAnimator([0, 1, 2], trigger: state.trigger) { phase in
                PhaseNumber(value: Double(phase))
                p { state.label }
            } animation: { _ in
                selectedDurations.append(duration)
                return .linear(duration: duration)
            }
        }
        dom.flushMicrotasks()
        state.trigger += 1
        dom.flushMicrotasks()
        state.duration = 2
        state.label = "updated"
        dom.flushMicrotasks()
        #expect(selectedDurations == [1])
        #expect(dom.ops.contains(.patchText(node: "initial", to: "updated")))
        dom.advanceTime(by: 1.1)
        #expect(selectedDurations == [1, 2])
        dom.advanceTime(by: 1.1)
        #expect(selectedDurations == [1, 2])
        dom.advanceTime(by: 1.1)
        #expect(selectedDurations == [1, 2, 2])
        app.unmount()
    }

    @Test
    func zeroDurationAndDuplicatePhasesCompleteNormally() {
        let state = PhaseInputs()
        let dom = TestDOM()
        var targets: [Int] = []
        let app = dom.mount {
            PhaseAnimator([0, 1, 1, 2], trigger: state.trigger) { phase in
                PhaseNumber(value: Double(phase))
            } animation: {
                targets.append($0)
                return .linear(duration: 0)
            }
        }
        dom.flushMicrotasks()
        state.trigger += 1
        dom.flushMicrotasks()
        for _ in 0..<4 { dom.advanceTime(by: 0.01) }
        #expect(targets == [1, 1, 2, 0])
        app.unmount()
    }

    @Test
    func instancesAndRemountsHaveIndependentPlayback() {
        let state = PhaseInputs()
        let dom = TestDOM()
        var first: [Int] = []
        var second: [Int] = []
        let app = dom.mount {
            div {
                if state.visible {
                    PhaseAnimator([0, 1], trigger: state.trigger) {
                        PhaseNumber(value: Double($0))
                    } animation: {
                        first.append($0)
                        return .linear(duration: 1)
                    }
                }
                PhaseAnimator([0, 1], trigger: 0) {
                    PhaseNumber(value: Double($0))
                } animation: {
                    second.append($0)
                    return .linear(duration: 1)
                }
            }
        }
        dom.flushMicrotasks()
        state.trigger += 1
        dom.flushMicrotasks()
        #expect(first == [1])
        #expect(second.isEmpty)
        state.visible = false
        dom.flushMicrotasks()
        state.visible = true
        dom.flushMicrotasks()
        dom.advanceTime(by: 2)
        #expect(first == [1])
        state.trigger += 1
        dom.flushMicrotasks()
        #expect(first == [1, 1])
        #expect(second.isEmpty)
        app.unmount()
    }

    @Test
    func unmountInvalidatesQueuedAndRunningWork() {
        let dom = TestDOM()
        var targets: [Int] = []
        var releasedChildren = 0
        let app = dom.mount {
            PhaseAnimator([0, 1]) { phase in
                PhaseNumber(value: Double(phase))
                DeinitSnifferView { releasedChildren += 1 }
            } animation: {
                targets.append($0)
                return .linear(duration: 1)
            }
        }
        dom.flushMicrotasks()
        #expect(targets == [1])
        app.unmount()
        dom.advanceTime(by: 5)
        #expect(releasedChildren == 1)
        #expect(targets == [1])
        let second = dom.mount {
            PhaseAnimator([0, 1]) {
                PhaseNumber(value: Double($0))
            } animation: {
                targets.append($0)
                return .linear(duration: 1)
            }
        }
        second.unmount()
        dom.advanceTime(by: 5)
        #expect(targets == [1])
    }
}

@Reactive
private final class PhaseInputs {
    var trigger = 0
    var phases = [0, 1, 2]
    var label = "initial"
    var duration = 1.0
    var visible = true
}

@View
private struct PhaseNumber: Animatable {
    var value: Double
    var animatableValue: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View { p { "\(value)" } }
}

@View
private struct StatefulPhaseChild {
    var label: String
    @State var count = 0
    var body: some View {
        p { "\(label):\(count)" }.onAppear { count += 1 }
    }
}
