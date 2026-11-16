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
}

private final class TransactionTestLog {
    var entries: [String] = []
}

@Reactive
private final class TransactionTestState {
    var visible = true
}
