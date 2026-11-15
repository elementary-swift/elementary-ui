import Reactivity
import Testing

@testable @_spi(Benchmarking) import ElementaryUI

@MainActor
@Suite
struct UnmountOrderTests {
    @Test
    func removedSlotUnmountsChildrenBeforeParentsInSourceOrder() {
        let state = UnmountOrderState()
        let log = UnmountLog()
        let dom = TestDOM()
        dom.mount {
            Group {
                if state.visible {
                    OrderedContent(log: log)
                }
            }
        }
        dom.runNextFrame()

        state.visible = false
        dom.runNextFrame()

        #expect(log.entries == OrderedContent.expectedOrder)
    }

    @Test
    func elementModifiersUnmountAfterChildren() {
        let state = UnmountOrderState()
        let log = UnmountLog()
        let dom = TestDOM()
        dom.mount {
            Group {
                if state.visible {
                    DOMEffectView<LoggingModifier, _>(
                        value: LoggingModifier.Value(log: log, name: "div.modifier"),
                        wrapped: div {
                            DOMEffectView<LoggingModifier, _>(
                                value: LoggingModifier.Value(log: log, name: "p.modifier"),
                                wrapped: p {}
                            )
                        }
                    )
                }
            }
        }
        dom.runNextFrame()

        state.visible = false
        dom.runNextFrame()

        // onDisappear runs as a deferred effect; modifiers unmount in place
        #expect(log.entries == ["p.modifier", "div.modifier"])
    }

    @Test
    func appUnmountRunsRootRegistryInOrder() {
        let log = UnmountLog()
        let dom = TestDOM()
        let app = dom.mount {
            OrderedContent(log: log)
        }
        dom.runNextFrame()
        #expect(log.entries.isEmpty)

        app.unmount()
        dom.flushMicrotasks()

        #expect(log.entries == OrderedContent.expectedOrder)
    }

    @Test
    func keyedRemovalOnlyUnmountsDroppedSlot() {
        let state = UnmountOrderState()
        let log = UnmountLog()
        let dom = TestDOM()
        dom.mount {
            ForEach(state.items, id: \.self) { item in
                div {
                    span {}.onDisappear { log.entries.append("\(item).span") }
                }
                .onDisappear { log.entries.append("\(item).div") }
            }
        }
        dom.runNextFrame()

        state.items = ["a", "c"]
        dom.runNextFrame()
        #expect(log.entries == ["b.span", "b.div"])

        state.items = []
        dom.runNextFrame()
        // removed slots unmount last-first, as before
        #expect(log.entries == ["b.span", "b.div", "c.span", "c.div", "a.span", "a.div"])
    }

    @Test
    func exitTransitionDefersUnmountUntilFinished() {
        let state = UnmountOrderState()
        let log = UnmountLog()
        let dom = TestDOM()
        dom.mount {
            Group {
                if state.visible {
                    div {
                        p {}.onDisappear { log.entries.append("p") }
                    }
                    .transition(.fade, animation: .linear(duration: 0.35))
                }
            }
        }
        dom.runNextFrame()

        state.visible = false
        dom.runNextFrame()
        #expect(log.entries.isEmpty)

        dom.finishAnimations()
        dom.flushMicrotasks()
        #expect(log.entries == ["p"])
    }

    @Test
    func revivedLeavingSlotDoesNotUnmount() {
        let state = UnmountOrderState()
        let log = UnmountLog()
        let dom = TestDOM()
        dom.mount {
            Group {
                if state.visible {
                    div {
                        p {}.onDisappear { log.entries.append("p") }
                    }
                    .transition(.fade, animation: .linear(duration: 0.35))
                }
            }
        }
        dom.runNextFrame()

        state.visible = false
        dom.runNextFrame()
        state.visible = true
        dom.runNextFrame()
        dom.finishAnimations()
        dom.flushMicrotasks()
        #expect(log.entries.isEmpty)

        state.visible = false
        dom.runNextFrame()
        dom.finishAnimations()
        dom.flushMicrotasks()
        #expect(log.entries == ["p"])
    }
}

@View
private struct OrderedContent {
    static let expectedOrder = ["p", "a", "b", "inner", "span", "div"]

    let log: UnmountLog

    var body: some View {
        div {
            p {}.onDisappear { log.entries.append("p") }
            ForEach(["a", "b"], id: \.self) { item in
                span {}.onDisappear { log.entries.append(item) }
            }
            Group {
                if true {
                    span {}.onDisappear { log.entries.append("inner") }
                }
            }
            span {}.onDisappear { log.entries.append("span") }
        }
        .onDisappear { log.entries.append("div") }
    }
}

private final class LoggingModifier: DOMElementModifier, Unmountable {
    struct Value {
        let log: UnmountLog
        let name: String
    }

    private let value: Value

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, ctx: inout _MountContext) {
        self.value = value
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {}

    func mount(_ node: DOM.Node, _ context: inout _MountContext) {
        context.registerUnmount(self)
    }

    func unmount(_ context: inout _CommitContext) {
        value.log.entries.append(value.name)
    }
}

private final class UnmountLog {
    var entries: [String] = []
}

@Reactive
private final class UnmountOrderState {
    var visible = true
    var items = ["a", "b", "c"]
}
