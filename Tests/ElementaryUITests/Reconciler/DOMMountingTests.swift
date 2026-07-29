import ElementaryUI
import Reactivity
import Testing

struct DOMMountingTests {
    let svgNamespaceURI = "http://www.w3.org/2000/svg"

    private enum TestActionA: _DOMEventConfig {
        static let name = "action-a"
    }

    private enum TestActionB: _DOMEventConfig {
        static let name = "action-b"
    }

    @Test
    func mountsAnElement() {
        let ops = mountOps { div { "Hello" } }

        #expect(
            ops == [
                .createElement("div"),
                .createText("Hello"),
                .addChild(parent: "<div>", child: "Hello"),
                .addChild(parent: "<>", child: "<div>"),
            ]
        )
    }

    @Test
    func setsAttributes() {
        let ops = mountOps {
            input(.id("not-foo"), .type(.checkbox), .checked)
                .attributes(.hidden, .autofocus, .id("foo"), when: true)
                .attributes(.inert, when: false)
        }

        #expect(
            ops == [
                .createElement("input"),
                .setAttr(node: "<input>", name: "id", value: "foo"),
                .setAttr(node: "<input>", name: "type", value: "checkbox"),
                .setAttr(node: "<input>", name: "checked", value: nil),
                .setAttr(node: "<input>", name: "hidden", value: nil),
                .setAttr(node: "<input>", name: "autofocus", value: nil),
                .addChild(parent: "<>", child: "<input>"),
            ]
        )
    }

    @Test
    func setsNestedAttributes() {
        let ops = mountOps {
            div {
                p(.id("1")) {
                    span {}
                }
            }.attributes(.class("foo"))
        }

        #expect(
            ops == [
                .createElement("div"),
                .setAttr(node: "<div>", name: "class", value: "foo"),
                .createElement("p"),
                .setAttr(node: "<p>", name: "id", value: "1"),
                .createElement("span"),
                .addChild(parent: "<p>", child: "<span>"),
                .addChild(parent: "<div>", child: "<p>"),
                .addChild(parent: "<>", child: "<div>"),
            ]
        )
    }

    @Test
    func setsEventListeners() {
        let dom = TestDOM()
        dom.mount { button {}.onClick { _ in } }
        dom.runNextFrame()

        #expect(
            dom.ops == [
                .createElement("button"),
                .addListener(node: "<button>", event: "click"),
                .addChild(parent: "<>", child: "<button>"),
            ]
        )
        #expect(dom.eventSinkKinds == [.event])
    }

    @Test
    func setsNoArgumentEventListeners() {
        let dom = TestDOM()
        dom.mount { button {}.onClick {} }
        dom.runNextFrame()

        #expect(
            dom.ops == [
                .createElement("button"),
                .addListener(node: "<button>", event: "click"),
                .addChild(parent: "<>", child: "<button>"),
            ]
        )
        #expect(dom.eventSinkKinds == [.action])
    }

    @Test
    func keepsDifferentNoArgumentEventNamesSeparate() {
        let dom = TestDOM()
        dom.mount {
            button {}
                ._onEvent(TestActionA.self) {}
                ._onEvent(TestActionB.self) {}
        }
        dom.runNextFrame()

        #expect(
            dom.ops == [
                .createElement("button"),
                .addListener(node: "<button>", event: "action-a"),
                .addListener(node: "<button>", event: "action-b"),
                .addChild(parent: "<>", child: "<button>"),
            ]
        )
        #expect(dom.eventSinkKinds == [.action, .action])
    }

    @Test
    func mountsFragment() {
        let ops = mountOps {
            ul {
                li { "Text" }
                li { p {} }
            }
        }

        let liCreateCount = ops.filter { op in
            if case .createElement("li") = op { return true }
            return false
        }.count

        #expect(liCreateCount == 2)
        #expect(ops.contains(.createElement("ul")))
        #expect(ops.contains(.createText("Text")))
        #expect(ops.contains(.createElement("p")))
        #expect(ops.contains(.addChild(parent: "<ul>", child: "<li>")))
        #expect(ops.contains(.addChild(parent: "<>", child: "<ul>")))
    }

    @Test
    func mountsDynamicList() {
        #expect(
            mountOps {
                div {
                    for _ in 0..<2 {
                        p {}
                    }
                }
            } == [
                .createElement("div"),
                .createElement("p"),
                .createElement("p"),
                .addChild(parent: "<div>", child: "<p>"),
                .addChild(parent: "<div>", child: "<p>"),
                .addChild(parent: "<>", child: "<div>"),
            ]
        )
    }

    @Test
    func mountsSiblingStaticSubtreesWithoutLeakingChildScratch() {
        #expect(
            mountOps {
                div {
                    p { "Left" }
                    span { "Right" }
                }
            } == [
                .createElement("div"),
                .createElement("p"),
                .createText("Left"),
                .addChild(parent: "<p>", child: "Left"),
                .createElement("span"),
                .createText("Right"),
                .addChild(parent: "<span>", child: "Right"),
                .addChild(parent: "<div>", child: "<p>"),
                .addChild(parent: "<div>", child: "<span>"),
                .addChild(parent: "<>", child: "<div>"),
            ]
        )
    }

    @Test
    func mountsSVGElementsWithNamespace() {
        let ops = mountOps {
            SVG.svg(.viewBox(0, 0, 24, 24)) {
                SVG.rect(.x(1), .y(2), .width(10), .height(11), .fill("red"))
            }
        }

        #expect(
            ops == [
                .createElementNS(namespaceURI: svgNamespaceURI, element: "svg"),
                .setAttr(node: "<svg>", name: "viewBox", value: "0 0 24 24"),
                .createElementNS(namespaceURI: svgNamespaceURI, element: "rect"),
                .setAttr(node: "<rect>", name: "x", value: "1"),
                .setAttr(node: "<rect>", name: "y", value: "2"),
                .setAttr(node: "<rect>", name: "width", value: "10"),
                .setAttr(node: "<rect>", name: "height", value: "11"),
                .setAttr(node: "<rect>", name: "fill", value: "red"),
                .addChild(parent: "<svg>", child: "<rect>"),
                .addChild(parent: "<>", child: "<svg>"),
            ]
        )
    }

    @Test
    func mountsNestedSVGContent() {
        let ops = mountOps {
            SVG.svg {
                SVG.g {
                    SVG.circle(.cx(4), .cy(5), .r(6))
                    if true {
                        SVG.text(.x(1), .y(2)) { "Hi" }
                    }
                    for index in [1, 2] {
                        SVG.rect(.x(.init(index)), .y(0), .width(1), .height(1))
                    }
                }
            }
        }

        #expect(ops.contains(.createElementNS(namespaceURI: svgNamespaceURI, element: "svg")))
        #expect(ops.contains(.createElementNS(namespaceURI: svgNamespaceURI, element: "g")))
        #expect(ops.contains(.createElementNS(namespaceURI: svgNamespaceURI, element: "circle")))
        #expect(ops.contains(.createElementNS(namespaceURI: svgNamespaceURI, element: "text")))
        #expect(ops.contains(.createText("Hi")))
        #expect(ops.filter { if case .createElementNS(_, "rect") = $0 { true } else { false } }.count == 2)
    }

    @Test
    func patchesSVGAttributesFromReactiveView() {
        let state = SVGTestState()
        let ops = patchOps {
            SVG.svg {
                ReactiveRect(state: state)
            }
        } toggle: {
            state.isFilled = true
        }

        #expect(ops.contains(.setAttr(node: "<rect>", name: "fill", value: "red")))
    }

    @Test
    func mountsConditionals() {
        let ops = mountOps {
            div {
                if false {
                    p {}
                } else {
                    if true {
                        a {}
                    }
                }
            }
        }

        #expect(
            ops == [
                .createElement("div"),
                .createElement("a"),
                .addChild(parent: "<div>", child: "<a>"),
                .addChild(parent: "<>", child: "<div>"),
            ]
        )
    }

    @Test
    func mountsSwitch() {
        #expect(
            mountOps {
                switch 2 {
                case 0:
                    p { "Zero" }
                case 1:
                    p { "One" }
                default:
                    p { "Two" }
                }
            } == [
                .createElement("p"),
                .createText("Two"),
                .addChild(parent: "<p>", child: "Two"),
                .addChild(parent: "<>", child: "<p>"),
            ]
        )
    }

    @Test
    func mountsStatelessFunction() {
        #expect(
            mountOps {
                TestView(text: "Hello")
            } == [
                .createElement("p"),
                .createText("Hello"),
                .addChild(parent: "<p>", child: "Hello"),
                .addChild(parent: "<>", child: "<p>"),
            ]
        )
    }

    @Test
    func mountsStatefulFunction() {
        #expect(
            mountOps {
                TestViewWithState()
            } == [
                .createElement("p"),
                .createText("12"),
                .addChild(parent: "<p>", child: "12"),
                .addChild(parent: "<>", child: "<p>"),
            ]
        )
    }

    @Test
    func mountsArray() {
        #expect(
            mountOps {
                for i in 0..<2 {
                    "Item \(i)"
                }
            } == [
                .createText("Item 0"),
                .createText("Item 1"),
                .addChild(parent: "<>", child: "Item 0"),
                .addChild(parent: "<>", child: "Item 1"),
            ]
        )
    }

    @Test
    func mountsKeyedForEach() {
        #expect(
            mountOps {
                ForEach(0..<2, key: \.self) { i in
                    "Item \(i)"
                }
            } == [
                .createText("Item 0"),
                .createText("Item 1"),
                .addChild(parent: "<>", child: "Item 0"),
                .addChild(parent: "<>", child: "Item 1"),
            ]
        )
    }

    @Test
    func mountsGroup() {
        #expect(
            mountOps {
                Group {
                    p { "First" }
                }
            } == [
                .createElement("p"),
                .createText("First"),
                .addChild(parent: "<p>", child: "First"),
                .addChild(parent: "<>", child: "<p>"),
            ]
        )
    }

    @Test
    func mountsDistinctTypedKeysForSameRenderedValue() {
        let ops = mountOps {
            Group {
                p { "string" }.key("1")
                p { "number" }.key(1)
            }
        }

        let createdPCount = ops.filter { op in
            if case .createElement("p") = op { return true }
            return false
        }.count

        #expect(createdPCount == 2)
    }
}

@Reactive
private class SVGTestState {
    var isFilled = false
}

@View
private struct ReactiveRect: SVGView {
    let state: SVGTestState

    var body: some SVGView {
        SVG.rect(.width(10), .height(10), .fill(state.isFilled ? "red" : "blue"))
    }
}

@View
private struct TestView {
    var text: String
    var body: some View {
        p { text }
    }
}

@View
private struct TestViewWithState {
    @State var number = 12
    var body: some View {
        p { "\(number)" }
    }
}
