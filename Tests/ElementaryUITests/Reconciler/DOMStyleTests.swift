import ElementaryUI
import Reactivity
import Testing

struct DOMStyleTests {
    @Test
    func mountsInlineStylesAsOps() {
        let ops = mountOps {
            p(.style(["color": "red"])) {}
        }

        #expect(
            ops == [
                .createElement("p"),
                .setStyle(node: "<p>", name: "color", value: "red"),
                .addChild(parent: "<>", child: "<p>"),
            ]
        )
    }

    @Test
    func updatesInlineStyleValuesAsOps() {
        let state = StyleToggleState()
        let ops = patchOps {
            p(.style(state.value ? ["color": "blue", "display": "grid"] : ["color": "red", "display": "grid"])) {}
        } toggle: {
            state.toggle()
        }

        #expect(ops == [.setStyle(node: "<p>", name: "color", value: "blue")])
    }

    @Test
    func removesInlineStylePropertiesAsOps() {
        let state = StyleToggleState()
        let ops = patchOps {
            p(.style(state.value ? ["color": "red"] : ["color": "red", "display": "grid"])) {}
        } toggle: {
            state.toggle()
        }

        #expect(ops == [.removeStyle(node: "<p>", name: "display")])
    }

    @Test
    func removesInlineStylesWhenStyleAttributeDisappearsAsOps() {
        let state = StyleToggleState()
        let ops = patchOps {
            p {}.attributes(.style(["color": "red", "display": "grid"]), when: !state.value)
        } toggle: {
            state.toggle()
        }

        #expect(
            ops == [
                .removeStyle(node: "<p>", name: "color"),
                .removeStyle(node: "<p>", name: "display"),
            ]
        )
    }

    @Test
    func patchesNonStyleAttributesAlongsideStylesAsOps() {
        let state = StyleToggleState()
        let ops = patchOps {
            p(
                .id(state.value ? "after" : "before"),
                .style(["color": state.value ? "blue" : "red"])
            ) {}
        } toggle: {
            state.toggle()
        }

        #expect(
            ops == [
                .setAttr(node: "<p>", name: "id", value: "after"),
                .setStyle(node: "<p>", name: "color", value: "blue"),
            ]
        )
    }

    @Test
    func patchesStyleShuffleAddRemoveAndValueChangeAsOps() {
        let state = StyleToggleState()
        let ops = patchOps {
            p(.style(state.value ? ["b": "20", "d": "4", "a": "1"] : ["a": "1", "b": "2", "c": "3"])) {}
        } toggle: {
            state.toggle()
        }

        #expect(
            ops == [
                .setStyle(node: "<p>", name: "b", value: "20"),
                .setStyle(node: "<p>", name: "d", value: "4"),
                .removeStyle(node: "<p>", name: "c"),
            ]
        )
    }
}

@Reactive
private final class StyleToggleState {
    var value = false

    func toggle() {
        value.toggle()
    }
}
