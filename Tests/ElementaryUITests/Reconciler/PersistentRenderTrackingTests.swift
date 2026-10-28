import Reactivity
import Testing

@testable import ElementaryUI

// Serialized: `withAnimation` sets the global `Transaction._current`, which would split
// the bursts counted by the other tests.
@Suite(.serialized)
struct PersistentRenderTrackingTests {
    @Test func replacesConditionalDependenciesAndRearmsAfterEachRender() {
        let model = ListenerRenderModel()
        let probe = ListenerRenderProbe()
        let dom = TestDOM()
        let app = dom.mount { ListenerRenderView(model: model, probe: probe) }
        dom.flushMicrotasks()
        #expect(probe.renders == 1)
        for value in 1...10 { model.first = value }
        dom.flushMicrotasks()
        #expect(probe.renders == 2)
        model.first = 11
        dom.flushMicrotasks()
        #expect(probe.renders == 3)
        model.useFirst = false
        dom.flushMicrotasks()
        #expect(probe.renders == 4)
        model.first = 12
        dom.flushMicrotasks()
        #expect(probe.renders == 4)
        model.second = 1
        dom.flushMicrotasks()
        #expect(probe.renders == 5)
        app.unmount()
        dom.flushMicrotasks()
        model.second = 2
        #expect(!dom.hasWorkScheduled)
        #expect(dom.queueMicrotaskCallbacks.isEmpty)
        #expect(probe.renders == 5)
    }

    @Test func sharedModelInvalidatesEachOwningApplication() {
        let model = ListenerRenderModel()
        let firstProbe = ListenerRenderProbe()
        let secondProbe = ListenerRenderProbe()
        let firstDOM = TestDOM()
        let secondDOM = TestDOM()
        let first = firstDOM.mount { ListenerRenderView(model: model, probe: firstProbe) }
        let second = secondDOM.mount { ListenerRenderView(model: model, probe: secondProbe) }
        firstDOM.flushMicrotasks()
        secondDOM.flushMicrotasks()
        model.first = 1
        #expect(firstDOM.queueMicrotaskCallbacks.count == 1)
        #expect(secondDOM.queueMicrotaskCallbacks.count == 1)
        firstDOM.flushMicrotasks()
        #expect(firstProbe.renders == 2)
        #expect(secondProbe.renders == 1)
        secondDOM.flushMicrotasks()
        #expect(secondProbe.renders == 2)
        first.unmount()
        firstDOM.flushMicrotasks()
        model.first = 2
        #expect(!firstDOM.hasWorkScheduled)
        #expect(firstDOM.queueMicrotaskCallbacks.isEmpty)
        secondDOM.flushMicrotasks()
        #expect(firstProbe.renders == 2)
        #expect(secondProbe.renders == 3)
        second.unmount()
    }

    @Test func unmountReleasesNodeOwnedViewAndCancelsBeforeDisappearWrites() {
        let model = ListenerRenderModel()
        let lifetime = ListenerRenderLifetime()
        let dom = TestDOM()
        let app = dom.mount {
            ListenerRenderView(model: model, probe: ListenerRenderProbe(lifetime: lifetime))
                .onDisappear { model.first += 1 }
        }
        dom.flushMicrotasks()
        #expect(lifetime.deaths == 0)
        app.unmount()
        dom.flushMicrotasks()
        #expect(lifetime.deaths == 1)
        model.first += 1
        #expect(!dom.hasWorkScheduled)
        #expect(dom.queueMicrotaskCallbacks.isEmpty)
    }

    @Test func separateTransactionsRemainSeparateBursts() {
        let model = ListenerRenderModel()
        let probe = ListenerRenderProbe()
        let dom = TestDOM()
        let app = dom.mount { ListenerRenderView(model: model, probe: probe) }
        dom.flushMicrotasks()
        model.first = 1
        withAnimation { model.first = 2 }
        dom.flushMicrotasks()
        #expect(probe.renders == 3)
        app.unmount()
    }

    @Test func childInvalidatedTogetherWithTheParentThatRemovesItIsNotRunAfterUnmount() {
        let model = ListenerRenderModel()
        let probe = ListenerRenderProbe()
        let dom = TestDOM()
        let app = dom.mount { ListenerRenderParentView(model: model, probe: probe) }
        dom.flushMicrotasks()
        #expect(probe.renders == 1)
        model.first = 1  // queues the child
        model.useFirst = false  // queues the parent, which removes the child
        dom.flushMicrotasks()
        model.first = 2
        dom.flushMicrotasks()
        #expect(!dom.hasWorkScheduled)
        #expect(probe.renders <= 2)
        app.unmount()
    }
}

@Reactive private final class ListenerRenderModel {
    var useFirst = true
    var first = 0
    var second = 0
}
private final class ListenerRenderLifetime { var deaths = 0 }
private final class ListenerRenderProbe {
    var renders = 0
    let lifetime: ListenerRenderLifetime?
    init(lifetime: ListenerRenderLifetime? = nil) { self.lifetime = lifetime }
    func recordRender() { renders += 1 }
    deinit { lifetime?.deaths += 1 }
}
@View private struct ListenerRenderParentView {
    let model: ListenerRenderModel
    let probe: ListenerRenderProbe
    var body: some View {
        if model.useFirst {
            ListenerRenderChildView(model: model, probe: probe)
        }
    }
}
@View private struct ListenerRenderChildView {
    let model: ListenerRenderModel
    let probe: ListenerRenderProbe
    var body: some View {
        let _ = probe.recordRender()
        p { "\(model.first)" }
    }
}
@View private struct ListenerRenderView {
    let model: ListenerRenderModel
    let probe: ListenerRenderProbe
    var body: some View {
        let _ = probe.recordRender()
        p { "\(model.useFirst ? model.first : model.second)" }
    }
}
