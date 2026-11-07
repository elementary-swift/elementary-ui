import Reactivity
import Testing

@testable import ElementaryUI

struct DependencyPropagationTests {
    // Readers at equal depth run last-registered first (the pending queue pops from the back).
    @Test
    func environmentChangeRerunsEveryRow() {
        let model = PropagationModel()

        let calls = trackUpdating {
            RowsProvider(model: model)
        } toggle: {
            model.value += 1
        }

        #expect(calls == ["provider"] + (0..<20).reversed().map { "row \($0): 1" })
    }

    @Test
    func equalEnvironmentValueDoesNotRerunReaders() {
        let model = PropagationModel()

        let calls = trackUpdating {
            RowsProvider(model: model)
        } toggle: {
            model.unrelated += 1
        }

        #expect(calls == ["provider"])
    }

    @Test
    func removedReadersAreReleasedAndNotRerun() {
        let model = PropagationModel()
        let dom = TestDOM()
        let tracker = RenderTracker()
        var releasedCount = 0

        dom.mount {
            ConditionalReaders(model: model) { releasedCount += 1 }
                .environment(#Key(\.tracker), tracker)
        }
        dom.runNextFrame()

        model.isShown = false
        dom.runNextFrame()
        #expect(releasedCount == 3)

        tracker.reset()
        model.value += 1
        dom.runNextFrame()
        #expect(tracker.calls == ["conditional"])
    }

    @Test
    func shownAgainReadersFollowLaterChanges() {
        let model = PropagationModel()
        let dom = TestDOM()
        let tracker = RenderTracker()

        dom.mount {
            ConditionalReaders(model: model) {}
                .environment(#Key(\.tracker), tracker)
        }
        dom.runNextFrame()

        model.isShown = false
        dom.runNextFrame()
        model.isShown = true
        dom.runNextFrame()

        tracker.reset()
        model.value += 1
        dom.runNextFrame()
        #expect(tracker.calls == ["conditional", "reader 0: 1", "reader 1: 1", "reader 2: 1"])
    }

    @Test
    func outerAttributesFollowToEveryElement() {
        let model = PropagationModel()
        let ops = patchOps {
            _AttributedContent(
                content: AttributedRows(model: model),
                attributes: _AttributeStorage(MarkupAttribute<HTMLTag.div>.class(model.value == 0 ? "a" : "b"))
            )
        } toggle: {
            model.value += 1
        }

        #expect(
            ops == [
                .setAttr(node: "<p>", name: "class", value: "b"),
                .setAttr(node: "<span>", name: "class", value: "b"),
            ]
        )
    }

    // An element removed in the same transaction is still patched: slots unmount at commit.
    @Test
    func outerAttributesReachElementsRemovedInTheSameTransaction() {
        let model = PropagationModel()
        let ops = patchOps {
            _AttributedContent(
                content: AttributedRows(model: model),
                attributes: _AttributeStorage(MarkupAttribute<HTMLTag.div>.class(model.value == 0 ? "a" : "b"))
            )
        } toggle: {
            model.isShown = false
            model.value += 1
        }

        #expect(
            ops == [
                .setAttr(node: "<p>", name: "class", value: "b"),
                .setAttr(node: "<span>", name: "class", value: "b"),
                .removeChild(parent: "<>", child: "<span>"),
            ]
        )
    }

    @Test
    func nestedAttributeModifiersCombine() {
        let model = PropagationModel()
        let ops = patchOps {
            _AttributedContent(
                content: _AttributedContent(
                    content: p {},
                    attributes: _AttributeStorage(MarkupAttribute<HTMLTag.div>.id("inner"))
                ),
                attributes: _AttributeStorage(MarkupAttribute<HTMLTag.div>.class(model.value == 0 ? "a" : "b"))
            )
        } toggle: {
            model.value += 1
        }

        #expect(ops == [.setAttr(node: "<p>", name: "class", value: "b")])
    }

    @Test
    func opacityFollowsToEveryElement() {
        let model = PropagationModel()
        let ops = patchOps {
            OpacityRows(model: model)
        } toggle: {
            model.value += 1
        }

        #expect(
            ops == [
                .setStyle(node: "<p>", name: "opacity", value: "0.5"),
                .setStyle(node: "<span>", name: "opacity", value: "0.5"),
            ]
        )
    }

    @Test
    func nestedOpacityLayersCombine() {
        let model = PropagationModel()
        let ops = patchOps {
            p {}
                .opacity(model.value == 0 ? 1 : 0.5)
                .opacity(0.5)
        } toggle: {
            model.value += 1
        }

        #expect(ops == [.setStyle(node: "<p>", name: "opacity", value: "0.25")])
    }
}

@Reactive
private final class PropagationModel {
    var value = 0
    var unrelated = 0
    var isShown = true
}

extension EnvironmentValues {
    @Entry fileprivate var propagationValue: Int = 0
}

@View
private struct RowsProvider {
    let model: PropagationModel

    var body: some View {
        Track(
            name: "provider",
            wrapped: { [unrelated = model.unrelated] in
                let _ = unrelated
                ForEach(Array(0..<20), id: \.self) { index in
                    RowReader(index: index)
                }
            }
        )
        .environment(#Key(\.propagationValue), model.value)
    }
}

@View
private struct RowReader {
    let index: Int
    @Environment(#Key(\.propagationValue)) var value

    var body: some View {
        Track(name: "row \(index): \(value)") {}
    }
}

@View
private struct ConditionalReaders {
    let model: PropagationModel
    let onRelease: () -> Void

    var body: some View {
        Track(name: "conditional") {
            if model.isShown {
                ForEach(Array(0..<3), id: \.self) { index in
                    SniffedReader(index: index, onRelease: onRelease)
                }
            }
        }
        .environment(#Key(\.propagationValue), model.value)
    }
}

@View
private struct SniffedReader {
    let index: Int
    let onRelease: () -> Void
    @Environment(#Key(\.propagationValue)) var value

    var body: some View {
        Track(name: "reader \(index): \(value)") {
            DeinitSnifferView(callback: onRelease)
        }
    }
}

@View
private struct AttributedRows {
    let model: PropagationModel

    var body: some View {
        p {}
        if model.isShown {
            span {}
        }
    }
}

@View
private struct OpacityRows {
    let model: PropagationModel

    var body: some View {
        Group {
            p {}
            span {}
        }
        .opacity(model.value == 0 ? 1 : 0.5)
    }
}
