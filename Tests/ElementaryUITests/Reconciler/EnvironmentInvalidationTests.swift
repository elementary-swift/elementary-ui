import Reactivity
import Testing

@testable import ElementaryUI

struct EnvironmentInvalidationTests {
    @Test
    func rerunsReadersThatDeclareButDoNotReadTheValue() {
        let model = Model()

        let calls = trackUpdating {
            Provider(model: model) { DeclaringReader() }
        } toggle: {
            model.outer += 1
        }

        #expect(calls == ["Provider", "declaring"])
    }

    @Test
    func innerModifierShadowsOuterChanges() {
        let model = Model()

        let outerCalls = trackUpdating {
            NestedProviders(model: model)
        } toggle: {
            model.outer += 1
        }
        #expect(outerCalls == ["Nested"])

        let innerCalls = trackUpdating {
            NestedProviders(model: model)
        } toggle: {
            model.inner += 1
        }
        #expect(innerCalls == ["Nested", "value: 1"])
    }

    @Test
    func releasesAndSkipsUnmountedReaders() {
        let model = Model()
        model.isShown = true
        var releasedCount = 0
        let dom = TestDOM()
        let tracker = RenderTracker()
        dom.mount {
            Provider(model: model) {
                if model.isShown {
                    SniffingReader { releasedCount += 1 }
                }
            }
            .environment(#Key(\.tracker), tracker)
        }
        dom.runNextFrame()

        model.isShown = false
        dom.runNextFrame()
        #expect(releasedCount == 1)

        tracker.reset()
        model.outer += 1
        dom.runNextFrame()
        #expect(tracker.calls == ["Provider"])
    }
}

@Reactive
private final class Model {
    var outer = 0
    var inner = 0
    var isShown = false
}

extension EnvironmentValues {
    @Entry fileprivate var invalidationValue: Int = 0
}

@View
private struct Provider<Content: View> {
    let model: Model
    @ContentBuilder let content: Content

    var body: some View {
        Track(name: "Provider") {
            content
        }
        .environment(#Key(\.invalidationValue), model.outer)
    }
}

@View
private struct DeclaringReader {
    @Environment(#Key(\.invalidationValue)) var value

    var body: some View {
        Track(name: "declaring") {}
    }
}

@View
private struct ValueReader {
    @Environment(#Key(\.invalidationValue)) var value

    var body: some View {
        Track(name: "value: \(value)") {}
    }
}

@View
private struct NestedProviders {
    let model: Model

    var body: some View {
        Track(name: "Nested") {
            ValueReader()
                .environment(#Key(\.invalidationValue), model.inner)
        }
        .environment(#Key(\.invalidationValue), model.outer)
    }
}

@View
private struct SniffingReader {
    @Environment(#Key(\.invalidationValue)) var value
    let onRelease: () -> Void

    var body: some View {
        Track(name: "reader: \(value)") {
            DeinitSnifferView(callback: onRelease)
        }
    }
}
