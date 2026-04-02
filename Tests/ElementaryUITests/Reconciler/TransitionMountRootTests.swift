import Reactivity
import Testing

@testable import ElementaryUI

@Suite(.serialized)
struct TransitionMountRootTests {
    @Test
    func initialMountTransitionStartsAtIdentity() {
        let recorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            p {}
                .transition(RecordingFadeTransition(recorder: recorder), animation: .linear(duration: 0.35))
        }
        dom.runNextFrame()

        #expect(recorder.phases.first == .identity)
        #expect(!recorder.phases.contains(.willAppear))
    }

    @Test
    func topLevelTransitionReceivesEnterSignal() {
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
    func siblingTopLevelTransitionsAllReceiveEnterSignal() {
        let state = VisibilityState()
        let firstRecorder = TransitionPhaseRecorder()
        let secondRecorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            Group {
                if state.value {
                    p {}.transition(RecordingFadeTransition(recorder: firstRecorder))
                    span {}.transition(RecordingFadeTransition(recorder: secondRecorder))
                }
            }
        }
        dom.runNextFrame()
        #expect(firstRecorder.phases.isEmpty)
        #expect(secondRecorder.phases.isEmpty)

        withAnimation(.linear(duration: 0.35)) {
            state.value = true
        }
        dom.runNextFrame()

        #expect(firstRecorder.phases.contains(.willAppear))
        #expect(secondRecorder.phases.contains(.willAppear))
    }

    @Test
    func nestedTransitionsOnlyOuterRegistersWithMountRoot() {
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
        let state = VisibilityState(true)
        let recorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            Group {
                if state.value {
                    p {}.transition(RecordingFadeTransition(recorder: recorder))
                }
            }
        }
        dom.runNextFrame()
        recorder.reset()

        dom.clearOps()
        var noAnimationTx = Transaction(animation: nil)
        noAnimationTx.disablesAnimation = true
        withTransaction(noAnimationTx) {
            state.value = false
        }
        dom.runNextFrame()
        #expect(dom.ops.contains(.removeChild(parent: "<>", child: "<p>")))

        dom.clearOps()
        let previousCount = recorder.phases.count
        withAnimation(.linear(duration: 0.35)) {
            state.value = true
        }
        dom.runNextFrame()

        let newPhases = Array(recorder.phases.dropFirst(previousCount))
        #expect(newPhases.contains(.willAppear))
        #expect(dom.ops.contains(.createElement("p")))
    }

    @Test
    func transitionInNonRootChildContextDoesNotRegister() {
        let state = VisibilityState()
        let recorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            Group {
                if state.value {
                    div {
                        p {}
                            .transition(RecordingFadeTransition(recorder: recorder), animation: .linear(duration: 0.35))
                    }
                }
            }
        }
        dom.runNextFrame()
        recorder.reset()

        withAnimation(.linear(duration: 0.35)) {
            state.value = true
        }
        dom.runNextFrame()

        #expect(!recorder.phases.contains(.willAppear))
        #expect(recorder.phases.contains(.identity))
    }

    @Test
    func eagerNestedMountUnderAnimatedTransactionStartsWithWillAppear() {
        let state = StringItemsState()
        nonisolated(unsafe) let recorder = TransitionPhaseRecorder()
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: \.self) { item in
                Group {
                    if item == "A" {
                        p { item }.transition(RecordingFadeTransition(recorder: recorder))
                    }
                }
            }
        }
        dom.runNextFrame()
        recorder.reset()

        withAnimation(.linear(duration: 0.35)) {
            state.items = ["A"]
        }
        dom.runNextFrame()

        #expect(recorder.phases.contains(.willAppear))
    }

    @Test
    func animateContainerLayoutRemovalPathDoesNotCrash() {
        let state = VisibilityState(true)
        let dom = TestDOM()

        dom.mount {
            div {
                Group {
                    if state.value {
                        p {}.transition(.fade)
                    }
                }
            }
            .animateContainerLayout()
        }
        dom.runNextFrame()
        dom.clearOps()

        state.value = false
        dom.runNextFrame()

        #expect(dom.ops.contains(.removeChild(parent: "<div>", child: "<p>")))
    }

    @Test
    func animateContainerLayoutDirectRemovalDoesNotUseLeavingAbsolutePositioning() {
        let state = StringItemsState(["A"])
        let dom = TestDOM()

        dom.mount {
            div {
                ForEach(state.items, key: \.self) { item in
                    p { item }
                }
            }
            .animateContainerLayout()
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = []
        }
        dom.runNextFrame()

        #expect(dom.ops.contains(.removeChild(parent: "<div>", child: "<p>")))
        #expect(!dom.ops.contains(.setStyle(node: "<p>", name: "position", value: "absolute")))
    }

    @Test
    func animateContainerLayoutTransitionedLeavingReenterDoesNotRecreate() {
        let state = StringItemsState(["A"])
        let dom = TestDOM()

        dom.mount {
            div {
                ForEach(state.items, key: \.self) { item in
                    p { item }.transition(.fade)
                }
            }
            .animateContainerLayout()
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = []
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = ["A"]
        }
        dom.runNextFrame()

        #expect(!dom.ops.contains(.createElement("p")))
        #expect(!dom.ops.contains(.createText("A")))
    }

    @Test
    func unmountContainerWithOutOfBandLeavingDoesNotCrash() {
        let visible = VisibilityState(true)
        let items = StringItemsState(["A"])
        let dom = TestDOM()

        dom.mount {
            Group {
                if visible.value {
                    div {
                        ForEach(items.items, key: \.self) { item in
                            p { item }.transition(.fade)
                        }
                    }
                    .animateContainerLayout()
                }
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            items.items = []
        }
        dom.runNextFrame()
        dom.clearOps()

        visible.value = false
        dom.runNextFrame()

        #expect(dom.ops.contains(.removeChild(parent: "<>", child: "<div>")))
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
        #expect(dom.ops.filter { $0 == .addChild(parent: "<>", child: "<p>") }.count == 3)
    }

    @Test
    func keyedReinsertRevivesLeavingRootWithoutRecreate() {
        let state = StringItemsState(["A"])
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: \.self) { item in
                p { item }.transition(.fade)
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = []
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = ["A"]
        }
        dom.runNextFrame()

        #expect(!dom.ops.contains(.createElement("p")))
        #expect(!dom.ops.contains(.createText("A")))
    }

    @Test
    func keyedReviveFromOutsideMiddlePrefixAndSuffixWithoutRecreate() {
        let state = StringItemsState(["A", "B", "C", "D"])
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: \.self) { item in
                p { item }.transition(.fade)
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = ["B", "C"]
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = ["A", "X", "D"]
        }
        dom.runNextFrame()

        #expect(!dom.ops.contains(.createText("A")))
        #expect(!dom.ops.contains(.createText("D")))
        #expect(dom.ops.contains(.createText("X")))
    }

    @Test
    func keyedMixedReuseReviveAndInsertPreservesOrderWithoutRecreate() {
        let state = StringItemsState(["A", "B", "D"])
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: \.self) { item in
                p { item }.transition(.fade)
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = ["B", "D"]
        }
        dom.runNextFrame()
        dom.clearOps()

        withAnimation(.linear(duration: 0.35)) {
            state.items = ["B", "A", "X", "D"]
        }
        dom.runNextFrame()

        #expect(!dom.ops.contains(.createText("A")))
        #expect(!dom.ops.contains(.createText("B")))
        #expect(!dom.ops.contains(.createText("D")))
        #expect(dom.ops.contains(.createText("X")))

        let parentBeforeInsertCount = dom.ops.filter { op in
            op == .addChild(parent: "<>", child: "<p>", before: "<p>")
        }.count
        #expect(parentBeforeInsertCount == 2)
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
