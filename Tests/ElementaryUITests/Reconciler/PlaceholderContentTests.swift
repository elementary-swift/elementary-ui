import Reactivity
import Testing

@testable import ElementaryUI

@MainActor
@Suite
struct PlaceholderContentTests {
    @Test(arguments: [false, true])
    func liveInstancesReceiveUpdatesAndUnmountExactlyOnce(transition: Bool) {
        let inputs = PlaceholderInputs()
        let probe = PlaceholderProbe()
        let dom = TestDOM()
        let app = dom.mount {
            let label = inputs.label
            return Group {
                if transition {
                    div { PlaceholderChild(label: label, probe: probe) }
                        .transition(RepeatingTransition(inputs: inputs))
                } else {
                    PlaceholderChild(label: label, probe: probe)
                        .phaseAnimator([false, true], trigger: inputs.trigger) { content, phase in
                            RepeatedContent(content: content, inputs: inputs)
                                .opacity(phase ? 0.5 : 1)
                        }
                }
            }
        }
        dom.flushMicrotasks()
        #expect(probe.mounts == 1)
        #expect(probe.removals == 0)

        inputs.copies = 2
        dom.flushMicrotasks()
        #expect(probe.mounts == 2)
        inputs.label = "second"
        dom.flushMicrotasks()
        #expect(probe.labels.suffix(2) == ["second", "second"])
        #expect(probe.counts.suffix(2) == [1, 1])
        #expect(probe.mounts == 2)

        inputs.copies = 1
        dom.flushMicrotasks()
        #expect(probe.removals == 1)
        #expect(probe.deinits == 1)
        let before = probe.labels.count
        inputs.label = "third"
        dom.flushMicrotasks()
        #expect(probe.labels.count == before + 1)
        #expect(probe.labels.last == "third")

        inputs.copies = 0
        dom.flushMicrotasks()
        #expect(probe.removals == 2)
        #expect(probe.deinits == 2)
        inputs.label = "latest"
        dom.flushMicrotasks()
        #expect(probe.labels.last == "third")

        inputs.copies = 2
        dom.flushMicrotasks()
        #expect(probe.mounts == 4)
        #expect(probe.labels.suffix(2) == ["latest", "latest"])
        #expect(probe.counts.suffix(2) == [1, 1])
        app.unmount()
        #expect(probe.removals == 4)
        #expect(probe.deinits == 4)
    }

    @Test
    func phaseOnlyUpdatesDoNotEvaluateWrappedBody() {
        let inputs = PlaceholderInputs()
        let probe = PlaceholderProbe()
        let dom = TestDOM()
        let app = dom.mount {
            PlaceholderChild(label: inputs.label, probe: probe)
                .phaseAnimator([false, true], trigger: inputs.trigger) { content, phase in
                    content.opacity(phase ? 0.5 : 1)
                } animation: { _ in
                    .linear(duration: 1)
                }
        }
        dom.flushMicrotasks()
        inputs.trigger += 1
        dom.flushMicrotasks()
        // The trigger changed in the parent. Subsequent automatic phase changes
        // must not cause any additional wrapped-body evaluations.
        let before = probe.labels.count
        dom.finishAnimations()
        dom.runNextFrame()
        dom.finishAnimations()
        dom.runNextFrame()
        #expect(probe.labels.count == before)
        #expect(probe.mounts == 1)
        app.unmount()
        #expect(probe.removals == 1)
        #expect(probe.deinits == 1)
    }

    @Test
    func transitionPhaseChangesDoNotEvaluateWrappedBody() {
        let inputs = PlaceholderInputs()
        let probe = PlaceholderProbe()
        let dom = TestDOM()
        let app = dom.mount {
            Group {
                if inputs.visible {
                    div { PlaceholderChild(label: "child", probe: probe) }
                        .transition(.fade)
                }
            }
        }
        dom.flushMicrotasks()
        let before = probe.labels.count
        withAnimation(.linear(duration: 1)) { inputs.visible = false }
        dom.flushMicrotasks()
        #expect(probe.labels.count == before)
        #expect(probe.removals == 0)
        dom.finishAnimations()
        dom.runNextFrame()
        #expect(probe.labels.count == before)
        #expect(probe.removals == 1)
        #expect(probe.deinits == 1)
        app.unmount()
        #expect(probe.removals == 1)
    }

    @Test(arguments: ["html", "void", "svg"])
    func initiallyOmittedElementsMountWithLatestAttributes(kind: String) {
        let inputs = PlaceholderInputs()
        inputs.copies = 0
        let dom = TestDOM()
        let app = dom.mount {
            let label = inputs.label
            return Group {
                if kind == "html" {
                    div(.id(label)) {}.transition(RepeatingTransition(inputs: inputs))
                } else if kind == "void" {
                    input(.id(label)).transition(RepeatingTransition(inputs: inputs))
                } else {
                    SVG.svg(.id(label)) {}.transition(RepeatingTransition(inputs: inputs))
                }
            }
        }
        dom.flushMicrotasks()
        inputs.label = "latest"
        dom.flushMicrotasks()
        dom.clearOps()
        inputs.copies = 1
        dom.flushMicrotasks()
        let tag = kind == "html" ? "div" : kind == "void" ? "input" : "svg"
        #expect(dom.ops.contains(.setAttr(node: "<\(tag)>", name: "id", value: "latest")))
        #expect(!dom.ops.contains(.setAttr(node: "<\(tag)>", name: "id", value: "initial")))
        app.unmount()
    }

    @Test
    func nestedContentsDoNotUpdateEachOthersInstances() {
        let inputs = PlaceholderInputs()
        let probe = PlaceholderProbe()
        let dom = TestDOM()
        let app = dom.mount {
            PlaceholderChild(label: inputs.label, probe: probe)
                .phaseAnimator([false, true], trigger: inputs.trigger) { content, _ in
                    Group {
                        content; content
                    }
                } animation: { _ in
                    nil
                }
                .phaseAnimator([false, true], trigger: inputs.trigger) { content, _ in
                    Group {
                        content; content
                    }
                } animation: { _ in
                    nil
                }
        }
        dom.flushMicrotasks()
        #expect(probe.mounts == 4)
        inputs.label = "updated"
        dom.flushMicrotasks()
        #expect(probe.labels.suffix(4) == Array(repeating: "updated", count: 4))
        inputs.trigger += 1
        dom.flushMicrotasks()
        #expect(probe.mounts == 4)
        app.unmount()
        #expect(probe.removals == 4)
        #expect(probe.deinits == 4)
    }
}

@Reactive
private final class PlaceholderInputs {
    var label = "initial"
    var copies = 1
    var trigger = 0
    var visible = true
}

private final class PlaceholderProbe {
    var labels: [String] = []
    var counts: [Int] = []
    var mounts = 0
    var removals = 0
    var deinits = 0

    func record(_ label: String, count: Int) -> String {
        labels.append(label)
        counts.append(count)
        return label
    }
}

@View
private struct PlaceholderChild {
    var label: String
    var probe: PlaceholderProbe
    @State var count = 0

    var body: some View {
        p { probe.record(label, count: count) }
            .onAppear {
                probe.mounts += 1; count += 1
            }
            .onDisappear { probe.removals += 1 }
        DeinitSnifferView { probe.deinits += 1 }
    }
}

@View
private struct RepeatedContent<Content: View> {
    var content: Content
    var inputs: PlaceholderInputs

    var body: some View {
        for _ in 0..<inputs.copies { content }
    }
}

private struct RepeatingTransition: Transition {
    var inputs: PlaceholderInputs
    func body(content: Content, phase: TransitionPhase) -> some View {
        RepeatedContent(content: content, inputs: inputs)
    }
}
