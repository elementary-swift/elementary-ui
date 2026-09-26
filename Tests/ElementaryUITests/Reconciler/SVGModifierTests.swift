import ElementaryUI
import Reactivity
import Testing

struct SVGModifierTests {
    @Test
    func setsEventListenersOnSVGElements() {
        let dom = TestDOM()
        dom.mount {
            SVG.svg {
                SVG.rect(.x(1), .y(2), .width(10), .height(11)).onClick { _ in }
                SVG.circle(.cx(4), .cy(5), .r(6)).onClick {}
            }
        }
        dom.runNextFrame()

        #expect(dom.ops.contains(.addListener(node: "<rect>", event: "click")))
        #expect(dom.ops.contains(.addListener(node: "<circle>", event: "click")))
        #expect(dom.eventSinkKinds == [.event, .action])
    }

    @Test
    func setsStylesOnSVGElements() {
        let dom = TestDOM()
        dom.mount {
            SVG.svg {
                SVG.rect(.x(0), .y(0), .width(1), .height(1))
                    .opacity(0.5)
                    .offset(x: 10, y: 20)
                    .blur(radius: 3)
            }
        }
        dom.runNextFrame()

        #expect(dom.ops.contains(.setStyle(node: "<rect>", name: "opacity", value: "0.5")))
        #expect(dom.ops.contains(.setStyle(node: "<rect>", name: "transform", value: "translate(10.0px, 20.0px)")))
        #expect(dom.ops.contains(.setStyle(node: "<rect>", name: "filter", value: "blur(3.0px)")))
    }

    @Test
    func patchesStylesOnSVGElements() {
        let state = SVGStyleToggleState()
        let ops = patchOps {
            SVG.svg {
                SVG.rect(.x(0), .y(0), .width(1), .height(1)).opacity(state.value ? 1 : 0.5)
            }
        } toggle: {
            state.toggle()
        }

        #expect(ops == [.setStyle(node: "<rect>", name: "opacity", value: "1.0")])
    }

    @Test
    func fixesTheTransformBoxForRotationAndScaling() {
        let dom = TestDOM()
        dom.mount {
            SVG.svg {
                SVG.rect(.x(0), .y(0), .width(1), .height(1)).rotationEffect(.degrees(45))
                SVG.circle(.cx(1), .cy(1), .r(1)).offset(x: 1, y: 2)
            }
        }
        dom.runNextFrame()

        #expect(dom.ops.contains(.setStyle(node: "<rect>", name: "transform-box", value: "fill-box")))
        #expect(dom.ops.contains(.setStyle(node: "<rect>", name: "transform-origin", value: "50% 50%")))
        #expect(!dom.ops.contains { if case .setStyle(node: "<circle>", name: "transform-box", _) = $0 { true } else { false } })
    }
}

@Reactive
private final class SVGStyleToggleState {
    var value = false

    func toggle() {
        value.toggle()
    }
}
