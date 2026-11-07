import Reactivity
import Synchronization
import Testing

@testable import ElementaryUI

struct FocusStateTests {
    private enum Field: Hashable {
        case name
        case email
    }

    private func restored() -> FocusState<Field?> {
        let storage = _ViewStateStorage(capacity: 1)
        var state = FocusState<Field?>()
        state.__initializeState(storage: storage, index: 0)
        state.__restoreState(storage: storage, index: 0)
        return state
    }

    @Test
    func reportedFocusUpdatesAndNotifiesReaders() {
        let state = restored()
        let changes = Mutex(0)
        _ = withReactiveTracking({ state.wrappedValue }, onChange: { changes.withLock { $0 += 1 } })

        state.projectedValue.storage.reportFocus(value: .email)

        #expect(state.wrappedValue == .email)
        #expect(changes.withLock { $0 } == 1)
    }

    @Test
    func assigningFocusesTheRegisteredElement() {
        let state = restored()
        let name = FakeFocusable()
        let email = FakeFocusable()
        state.projectedValue.storage.register(name, for: .name)
        state.projectedValue.storage.register(email, for: .email)

        state.wrappedValue = .email
        #expect(email.focusCount == 1)
        #expect(name.focusCount == 0)

        state.projectedValue.storage.reportFocus(value: .email)
        state.wrappedValue = nil
        #expect(email.blurCount == 1)
    }

    @Test
    func unregisteringTheFocusedElementClearsFocus() {
        let state = restored()
        let name = FakeFocusable()
        state.projectedValue.storage.register(name, for: .name)
        state.projectedValue.storage.reportFocus(value: .name)

        state.projectedValue.storage.unregister(name, for: .name)

        #expect(state.wrappedValue == nil)
    }
}

private final class FakeFocusable: Focusable {
    var focusCount = 0
    var blurCount = 0

    func focus() { focusCount += 1 }
    func blur() { blurCount += 1 }
}
