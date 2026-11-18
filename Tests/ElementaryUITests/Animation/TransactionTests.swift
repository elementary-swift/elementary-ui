import Dispatch
import Reactivity
import Testing

@testable import ElementaryUI

@Suite
struct TransactionTests {
    @Test
    func changeWithoutAnimationIsNotAnimatedByAnotherThreadsTransaction() {
        let state = TransactionTestState()
        let removed = TransactionTestLog()
        let dom = TestDOM()
        dom.mount {
            Group {
                if state.visible {
                    div {
                        p {}.onDisappear { removed.entries.append("p") }
                    }
                    .transition(.fade)
                }
            }
        }
        dom.runNextFrame()

        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            withAnimation(.linear(duration: 1)) {
                entered.signal()
                release.wait()
            }
            finished.signal()
        }
        entered.wait()
        state.visible = false
        release.signal()
        finished.wait()

        dom.runNextFrame()
        #expect(removed.entries == ["p"])
    }

    @Test
    func nestedTransactionAppliesOnlyInsideAndOuterOneIsRestored() {
        let state = TransactionTestState()
        let removed = TransactionTestLog()
        let dom = TestDOM()
        dom.mount { FadingPair(state: state, removed: removed) }
        dom.runNextFrame()

        withAnimation(.linear(duration: 1)) {
            withTransaction(Transaction()) { state.visible = false }
            state.otherVisible = false
        }
        dom.runNextFrame()
        #expect(removed.entries == ["first"])

        dom.finishAnimations()
        dom.runNextFrame()
        #expect(removed.entries == ["first", "second"])
    }

    @Test
    func consecutiveTransactionsInOneTickAreKeptApart() {
        let state = TransactionTestState()
        let removed = TransactionTestLog()
        let dom = TestDOM()
        dom.mount { FadingPair(state: state, removed: removed) }
        dom.runNextFrame()

        withTransaction(Transaction()) { state.visible = false }
        withAnimation(.linear(duration: 1)) { state.otherVisible = false }
        dom.runNextFrame()
        #expect(removed.entries == ["first"])

        dom.finishAnimations()
        dom.runNextFrame()
        #expect(removed.entries == ["first", "second"])
    }
}

private final class TransactionTestLog {
    var entries: [String] = []
}

@Reactive
private final class TransactionTestState {
    var visible = true
    var otherVisible = true
}

@View
private struct FadingPair {
    var state: TransactionTestState
    var removed: TransactionTestLog

    var body: some View {
        if state.visible {
            div { p {}.onDisappear { removed.entries.append("first") } }
                .transition(.fade)
        }
        if state.otherVisible {
            div { p {}.onDisappear { removed.entries.append("second") } }
                .transition(.fade)
        }
    }
}
