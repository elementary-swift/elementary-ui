import ElementaryUI
import Reactivity
import Testing

struct DOMPatchingTests {
    @Test
    func patchesText() {
        let state = ToggleState()
        let ops = patchOps {
            HTMLText("\(state.value)")
        } toggle: {
            state.toggle()
        }

        #expect(ops == [.patchText(node: "false", to: "true")])
    }

    @Test
    func patchesAttributes() {
        let state = ToggleState()
        let ops = patchOps {
            div {
                p(.id("\(state.value)"), .style(["unchanged": "style"])) {}
                a {}.attributes(.hidden, when: !state.value)
            }
        } toggle: {
            state.toggle()
        }

        #expect(
            ops == [
                .setAttr(node: "<p>", name: "id", value: "true"),
                .removeAttr(node: "<a>", name: "hidden"),
            ]
        )
    }

    @Test func patchesOptionals() async throws {
        let state = ToggleState()
        let ops = patchOps {
            div {
                if state.value {
                    p {}
                }
                a {}
                if !state.value {
                    br()
                }
            }
        } toggle: {
            state.toggle()
        }

        #expect(
            ops == [
                .createElement("p"),
                .removeChild(parent: "<div>", child: "<br>"),
                .addChild(parent: "<div>", child: "<p>", before: "<a>"),
            ]
        )
    }

    @Test func patchesConditionals() async throws {
        let state = ToggleState()
        let ops = patchOps {
            div {
                if state.value {
                    p {}
                } else {
                    a {}
                }
            }
        } toggle: {
            state.toggle()
        }

        #expect(
            ops == [
                .createElement("p"),
                .addChild(parent: "<div>", child: "<p>"),
                .removeChild(parent: "<div>", child: "<a>"),
            ]
        )
    }

    @Test func patchesSwitch() async throws {
        let state = CounterState()
        let ops = patchOps {
            div {}
            switch state.number {
            case 0:
                p {}
            case 1:
                a {}
            default:
                br()
            }
            img()
        } toggle: {
            state.number += 1
        }

        #expect(
            ops == [
                .createElement("a"),
                .addChild(parent: "<>", child: "<a>", before: "<img>"),
                .removeChild(parent: "<>", child: "<p>"),
            ]
        )
    }

    @Test func patchesSwitchMultipleTimes() async throws {
        let state = CounterState()
        let dom = TestDOM()
        dom.mount {
            div {
                switch state.number {
                case 0:
                    p {}
                case 1:
                    a {}
                default:
                    br()
                }
            }
        }
        state.number += 1
        dom.runNextFrame()
        dom.clearOps()

        state.number += 1
        dom.runNextFrame()

        #expect(
            dom.ops == [
                .createElement("br"),
                .addChild(parent: "<div>", child: "<br>"),
                .removeChild(parent: "<div>", child: "<a>"),
            ]
        )
    }

    @Test
    func patchesArrayAdditions() {
        let state = CounterState()
        let ops = patchOps {
            for i in 0..<state.number {
                "Item \(i)"
            }
        } toggle: {
            state.number += 1
            state.number += 1
        }

        #expect(
            ops == [
                .createText("Item 0"),
                .createText("Item 1"),
                .addChild(parent: "<>", child: "Item 0"),
                .addChild(parent: "<>", child: "Item 1"),
            ]
        )
    }

    @Test
    func patchesArrayRemovals() {
        let state = CounterState()
        state.number = 2
        let ops = patchOps {
            for i in 0..<state.number {
                "Item \(i)"
            }
        } toggle: {
            state.number -= 1
        }

        #expect(
            ops == [
                .removeChild(parent: "<>", child: "Item 1")
            ]
        )
    }

    @Test
    func patchesKeyedForEachAdditionsAndRemovals() {
        let state = StringListState(["A", "B", "C"])
        let ops = patchOps {
            ForEach(state.items, key: \.self) { item in
                item
            }
        } toggle: {
            state.items.insert("D", at: 2)
            state.items.remove(at: 0)
        }

        #expect(
            ops == [
                .createText("D"),
                .addChild(parent: "<>", child: "D", before: "C"),
                .removeChild(parent: "<>", child: "A"),
            ]
        )
    }

    @Test
    func patchesKeyedMoves() {
        let state = StringListState(["A", "B", "C"])
        let ops = patchOps {
            ForEach(state.items, key: \.self) { item in
                item
            }
        } toggle: {
            state.items.swapAt(0, 2)
        }

        #expect(
            ops == [
                .addChild(parent: "<>", child: "B", before: "A"),
                .addChild(parent: "<>", child: "C", before: "B"),
            ]
        )
    }

    @Test
    func updatesPendingKeyedInsertionWithLatestPatchBeforeCommit() {
        let state = KeyedItemState()
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: \.id) { item in
                p { item.value }
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        state.items = [.init(id: 1, value: "A")]
        state.items = [.init(id: 1, value: "B")]
        dom.runNextFrame()

        #expect(!dom.ops.contains(.createText("A")))
        #expect(dom.ops.contains(.createText("B")))
    }

    @Test
    func pendingKeyedMiddleInsertionRemovedBeforeCommitProducesNoOps() {
        let state = KeyedItemState([
            .init(id: 1, value: "A"),
            .init(id: 3, value: "C"),
        ])
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: \.id) { item in
                p { item.value }
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        state.items = [
            .init(id: 1, value: "A"),
            .init(id: 2, value: "B"),
            .init(id: 3, value: "C"),
        ]
        state.items = [
            .init(id: 1, value: "A"),
            .init(id: 3, value: "C"),
        ]
        dom.runNextFrame()

        #expect(!dom.ops.contains(.createText("B")))
        #expect(dom.ops.isEmpty)
    }

    @Test
    func pendingKeyedInsertionUnderLayoutObserverStillMounts() {
        let state = StringListState()
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

        state.items = ["A"]
        dom.runNextFrame()

        #expect(
            dom.ops == [
                .createElement("p"),
                .createText("A"),
                .addChild(parent: "<p>", child: "A"),
                .addChild(parent: "<div>", child: "<p>"),
            ]
        )
    }

    @Test
    func patchesKeyedEmptyList() {
        let state = StringListState(["A", "B", "C"])
        let ops = patchOps {
            ForEach(state.items, key: \.self) { item in
                item
            }
        } toggle: {
            state.items.removeAll()
        }

        #expect(
            ops == [
                .setChildren(parent: "<>", children: [])
            ]
        )
    }

    @Test
    func patchesListReorderingWithRemovalsAndAdditions() {
        let state = StringListState(["A", "B", "C"])
        let ops = patchOps {
            ForEach(state.items, key: \.self) { item in
                item
            }
        } toggle: {
            state.items = ["C", "B", "D"]
        }

        #expect(
            ops == [
                .createText("D"),
                .addChild(parent: "<>", child: "D"),
                .addChild(parent: "<>", child: "C", before: "B"),
                .removeChild(parent: "<>", child: "A"),
            ]
        )
    }

    @Test
    func patchesKeyedMiddleWindowWithUnchangedEdges() {
        let state = StringListState(["A", "B", "C", "D", "E"])
        let ops = patchOps {
            ForEach(state.items, key: \.self) { item in
                item
            }
        } toggle: {
            state.items = ["A", "C", "X", "D", "E"]
        }

        #expect(
            ops == [
                .createText("X"),
                .addChild(parent: "<>", child: "X", before: "D"),
                .removeChild(parent: "<>", child: "B"),
            ]
        )
    }

    @Test
    func duplicateKeysAreUndefinedButDoNotTrap() {
        let state = StringListState(["A", "B"])
        let dom = TestDOM()

        dom.mount {
            ForEach(state.items, key: { _ in 0 }) { item in
                p { item }
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        state.items = ["X", "Y", "Z"]
        dom.runNextFrame()

        #expect(!dom.ops.isEmpty)
    }

    @Test
    func patchesForEachClosureReactiveState() {
        let items = ["A", "B"]
        nonisolated(unsafe) let state = CounterState()

        let dom = TestDOM()
        dom.mount {
            ForEach(items, key: \.self) { item in
                p(.class(item == items[state.number] ? "selected" : "")) {}
            }
        }
        dom.runNextFrame()
        dom.clearOps()

        state.number += 1
        dom.runNextFrame()

        #expect(
            dom.ops == [
                .setAttr(node: "<p>", name: "class", value: ""),
                .setAttr(node: "<p>", name: "class", value: "selected"),
            ]
        )
    }

    @Test
    func patchesNestedConditionals() {
        let state = StringListState([])
        let ops = patchOps {
            ForEach(state.items, key: \.self) { item in
                p {
                    if true {
                        item
                    }
                }
            }
        } toggle: {
            state.items = ["B", "C", "D"]
        }

        #expect(
            ops == [
                .createElement("p"),
                .createText("B"),
                .addChild(parent: "<p>", child: "B"),
                .createElement("p"),
                .createText("C"),
                .addChild(parent: "<p>", child: "C"),
                .createElement("p"),
                .createText("D"),
                .addChild(parent: "<p>", child: "D"),
                .addChild(parent: "<>", child: "<p>"),
                .addChild(parent: "<>", child: "<p>"),
                .addChild(parent: "<>", child: "<p>"),
            ]
        )
    }

    @Test
    func countsUp() {
        let state = CounterState()

        let dom = TestDOM()
        dom.mount {
            p { "\(state.number)" }
        }
        dom.runNextFrame()
        dom.clearOps()

        state.number += 1
        dom.runNextFrame()

        #expect(!dom.hasWorkScheduled)

        state.number += 1
        state.number += 1
        dom.runNextFrame()

        #expect(
            dom.ops == [
                .patchText(node: "0", to: "1"),
                .patchText(node: "1", to: "3"),
            ]
        )
        #expect(!dom.hasWorkScheduled)
    }

    @Test
    func deinitsConditionalNodes() {
        nonisolated(unsafe) var deinitCount = 0
        let state = ToggleState()
        _ = patchOps {
            div {
                if state.value {
                    EmptyHTML()
                } else {
                    DeinitSnifferView {
                        deinitCount += 1
                    }
                }
            }
        } toggle: {
            state.toggle()
        }

        #expect(deinitCount == 1)
    }

    @Test
    func deinitsKeyedNodes() {
        nonisolated(unsafe) var deinitCount = 0
        let state = StringListState(["A", "B", "C"])
        _ = patchOps {
            ForEach(state.items, key: \.self) { item in
                DeinitSnifferView {
                    deinitCount += 1
                }
            }
        } toggle: {
            state.items = ["B"]
        }

        #expect(deinitCount == 2)
    }

    @Test
    func deinitsNestedNodes() {
        nonisolated(unsafe) var deinitCount = 0
        let state = ToggleState()
        _ = patchOps {
            if !state.value {
                div {
                    if true {
                        DeinitSnifferView {
                            deinitCount += 1
                        }
                    }
                }
                for _ in 0..<4 {
                    DeinitSnifferView {
                        deinitCount += 2
                    }
                }
                ForEach(["A", "B"], key: \.self) { item in
                    p {}
                    p {
                        DeinitSnifferView {
                            deinitCount += 3
                        }
                    }
                }
            }
        } toggle: {
            state.toggle()
        }

        #expect(deinitCount == 15)
    }

    @Test
    func patchesGroup() {
        let state = ToggleState()
        let ops = patchOps {
            Group {
                p { "\(state.value)" }
                a { "Static" }
            }
        } toggle: {
            state.toggle()
        }

        #expect(
            ops == [
                .patchText(node: "false", to: "true")
            ]
        )
    }
}

@Reactive
private class ToggleState {
    var value = false

    func toggle() {
        value.toggle()
    }
}

@Reactive
private class CounterState {
    var number = 0
}

@Reactive
private class StringListState {
    var items: [String]

    init(_ items: [String] = []) {
        self.items = items
    }
}

private struct KeyedItem {
    let id: Int
    let value: String
}

@Reactive
private class KeyedItemState {
    var items: [KeyedItem]

    init(_ items: [KeyedItem] = []) {
        self.items = items
    }
}
