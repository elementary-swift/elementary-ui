import ElementaryUI
import Reactivity
import Synchronization
import Testing

@Suite
struct StateTests {
    @Test
    func initializesValueStorage() {
        let storage = _ViewStateStorage(capacity: 4)
        storage.initializeValueStorage(initialValue: 42, index: 0)
        storage.initializeValueStorage(initialValue: "hello", index: 1)

        storage[1] = "goodbye"

        #expect(storage[0] == 42)
        #expect(storage[1] == "goodbye")
    }

    @Test
    func restoresState() {
        let storage = _ViewStateStorage(capacity: 4)
        var state = State(wrappedValue: 42)
        state.__initializeState(storage: storage, index: 0)
        state.__restoreState(storage: storage, index: 0)
        state.wrappedValue += 1

        var state2 = State(wrappedValue: 42)
        state2.__restoreState(storage: storage, index: 0)

        #expect(state.wrappedValue == 43)
        #expect(state2.wrappedValue == 43)
    }

    @Test
    func createsBinding() {
        let storage = _ViewStateStorage(capacity: 4)
        var state = State(wrappedValue: 42)
        state.__initializeState(storage: storage, index: 0)
        state.__restoreState(storage: storage, index: 0)

        let binding = state.projectedValue

        binding.wrappedValue += 1

        #expect(state.wrappedValue == 43)
        #expect(binding.wrappedValue == 43)
    }

    @Test
    func createsBindingWithKeypath() {
        let storage = _ViewStateStorage(capacity: 4)
        var state = State(wrappedValue: TestState())
        state.__initializeState(storage: storage, index: 0)
        state.__restoreState(storage: storage, index: 0)

        let binding = state.projectedValue.value

        binding.wrappedValue += 1

        #expect(state.wrappedValue.value == 43)
        #expect(binding.wrappedValue == 43)
    }

    @Test
    func tracksReactiveChanges() {
        let storage = _ViewStateStorage(capacity: 4)
        var state1 = State(wrappedValue: 42)
        var state2 = State(wrappedValue: "no change")
        nonisolated(unsafe) var hasChanged = false

        state1.__initializeState(storage: storage, index: 0)
        state2.__initializeState(storage: storage, index: 1)
        state1.__restoreState(storage: storage, index: 0)
        state2.__restoreState(storage: storage, index: 1)

        withReactiveTracking {
            _ = state1.wrappedValue
        } onChange: {
            hasChanged = true
        }

        state2.wrappedValue = "changed"
        #expect(!hasChanged)
        state1.wrappedValue = 43
        #expect(hasChanged)
    }

    @Test
    func replacesReferenceValues() {
        let storage = _ViewStateStorage(capacity: 1)
        var state = State(wrappedValue: TestState())
        state.__initializeState(storage: storage, index: 0)
        state.__restoreState(storage: storage, index: 0)

        let assigned = TestState()
        state.wrappedValue = assigned
        #expect(state.wrappedValue === assigned)

        let bound = TestState()
        state.projectedValue.wrappedValue = bound
        #expect(state.wrappedValue === bound)
        #expect(state.wrappedValue.value == 42)
    }
}

private class TestState {
    var value: Int = 42
}

@Suite
struct StateTrackingTests {
    private final class ChangeCount: Sendable {
        let value = Mutex(0)
        func increment() { value.withLock { $0 += 1 } }
        var count: Int { value.withLock { $0 } }
    }

    private func restoredState(_ initialValue: Int) -> State<Int> {
        let storage = _ViewStateStorage(capacity: 1)
        var state = State(wrappedValue: initialValue)
        state.__initializeState(storage: storage, index: 0)
        state.__restoreState(storage: storage, index: 0)
        return state
    }

    @Test
    func wrapperAssignmentNotifiesReaders() {
        let state = restoredState(0)
        let changes = ChangeCount()
        _ = withReactiveTracking({ state.wrappedValue }, onChange: { changes.increment() })
        state.wrappedValue = 1
        #expect(changes.count == 1)
    }

    @Test
    func wrapperMutationNotifiesReaders() {
        let state = restoredState(0)
        let changes = ChangeCount()
        _ = withReactiveTracking({ state.wrappedValue }, onChange: { changes.increment() })
        state.wrappedValue += 1
        #expect(changes.count == 1)
        #expect(state.wrappedValue == 1)
    }

    @Test
    func bindingAssignmentNotifiesReaders() {
        let state = restoredState(0)
        let changes = ChangeCount()
        _ = withReactiveTracking({ state.wrappedValue }, onChange: { changes.increment() })
        state.projectedValue.wrappedValue = 2
        #expect(changes.count == 1)
    }
}
