import Reactivity
import Testing

@testable import ElementaryUI

@Suite(.serialized)
struct TransitionMountRootTests {
    @Test
    func firstTransitionConsumesMountRootTransitionPhase() {
        let animation = Animation.linear(duration: 0.35)
        let state = VisibilityState()
        let recorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            Group {
                if state.value {
                    p {}.transition(RecordingFadeTransition(recorder: recorder), animation: animation)
                }
            }
        }
        dom.runNextFrame()
        #expect(recorder.phases.isEmpty)

        state.value = true
        dom.runNextFrame()

        #expect(recorder.phases.contains(.willAppear))
    }

    @Test
    func nestedTransitionsOnlyFirstConsumesSignal() {
        let animation = Animation.linear(duration: 0.35)
        let state = VisibilityState()
        let outerRecorder = TransitionPhaseRecorder()
        let innerRecorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            Group {
                if state.value {
                    p {}
                        .transition(RecordingFadeTransition(recorder: innerRecorder), animation: animation)
                        .transition(RecordingFadeTransition(recorder: outerRecorder), animation: animation)
                }
            }
        }
        dom.runNextFrame()

        state.value = true
        dom.runNextFrame()

        #expect(outerRecorder.phases.contains(.willAppear))
        #expect(!innerRecorder.phases.contains(.willAppear))
        #expect(innerRecorder.phases.first == .identity)
    }

    @Test
    func keyedInsertionWithTransitionDoesWillAppearToIdentity() {
        let state = StringItemsState()
        nonisolated(unsafe) let recorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: \.self) { item in
                p { item }.transition(RecordingFadeTransition(recorder: recorder))
            }
        }
        dom.runNextFrame()
        #expect(recorder.phases.isEmpty)

        withAnimation(.linear(duration: 0.35)) {
            state.items = ["A"]
        }
        dom.runNextFrame()

        #expect(recorder.phases.contains(.willAppear))
    }

    @Test
    func conditionalFlipKeepsRemovalCancelRemovalSemantics() {
        let animation = Animation.linear(duration: 0.35)
        let state = VisibilityState(true)
        let recorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            Group {
                if state.value {
                    p {}.transition(RecordingFadeTransition(recorder: recorder), animation: animation)
                }
            }
        }
        dom.runNextFrame()
        recorder.reset()

        dom.clearOps()
        state.value = false
        dom.runNextFrame()
        #expect(dom.ops.contains(.removeChild(parent: "<>", child: "<p>")))

        dom.clearOps()
        let previousCount = recorder.phases.count
        state.value = true
        dom.runNextFrame()

        let newPhases = Array(recorder.phases.dropFirst(previousCount))
        #expect(newPhases.contains(.willAppear))
        #expect(dom.ops.contains(.createElement("p")))
    }

    @Test
    func noUninitializedNodesInPlacementCollection() {
        let state = StringItemsState()
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: \.self) { item in
                p { item }
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        state.items = ["A", "B", "C"]
        dom.runNextFrame()

        let createdPCount = dom.ops.filter { op in
            if case .createElement("p") = op { return true }
            return false
        }.count

        #expect(createdPCount == 3)
        #expect(
            dom.ops.contains(.setChildren(parent: "<>", children: ["<p>", "<p>", "<p>"]))
        )
    }

    // @Test
    // func schedulesOneDeferredCreateCommitCallbackPerOwnerPatchPass() {
    //     let state = StringItemsState(["A"])
    //     let dom = TestDOM()

    //     dom.mount {
    //         ForEach(state.items, key: \.self) { item in
    //             p { item }
    //         }
    //     }
    //     dom.runNextFrame()

    //     ReconcilerDebugCounters.reset()
    //     state.items = ["A", "B", "C", "D"]
    //     dom.runNextFrame()

    //     #expect(ReconcilerDebugCounters.deferredCreateCommitCallbackCount == 1)
    // }
}

private final class TransitionPhaseRecorder {
    private(set) var phases: [TransitionPhase] = []

    func record(_ phase: TransitionPhase) {
        phases.append(phase)
    }

    func reset() {
        phases.removeAll()
    }
}

private struct RecordingFadeTransition: Transition {
    let recorder: TransitionPhaseRecorder

    func body(content: Content, phase: TransitionPhase) -> some View {
        recorder.record(phase)
        return content.opacity(phase.isIdentity ? 1 : 0)
    }
}

@Reactive
private final class VisibilityState {
    var value: Bool

    init(_ value: Bool = false) {
        self.value = value
    }
}

@Reactive
private final class StringItemsState {
    var items: [String]

    init(_ items: [String] = []) {
        self.items = items
    }
}
