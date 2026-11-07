import ElementaryUI
import Reactivity
import Testing

@Suite
struct StateTests {
    @Test
    func initializesValueStorage() {
        let number = State(wrappedValue: 42)
        let text = State(wrappedValue: "hello")
        let storage = _ViewStateStorage(count: 2) { values in
            number.__initializeState(into: &values)
            text.__initializeState(into: &values)
        }

        storage[1] = "goodbye"

        #expect(storage[0] == 42)
        #expect(storage[1] == "goodbye")
    }

    @Test
    func restoresState() {
        var state = State(wrappedValue: 42)
        let storage = _ViewStateStorage(count: 1) { state.__initializeState(into: &$0) }
        state.__restoreState(storage: storage, index: 0)
        state.wrappedValue += 1

        var state2 = State(wrappedValue: 42)
        state2.__restoreState(storage: storage, index: 0)

        #expect(state.wrappedValue == 43)
        #expect(state2.wrappedValue == 43)
    }

    @Test
    func createsBinding() {
        var state = State(wrappedValue: 42)
        let storage = _ViewStateStorage(count: 1) { state.__initializeState(into: &$0) }
        state.__restoreState(storage: storage, index: 0)

        let binding = state.projectedValue

        binding.wrappedValue += 1

        #expect(state.wrappedValue == 43)
        #expect(binding.wrappedValue == 43)
    }

    @Test
    func createsBindingWithKeypath() {
        var state = State(wrappedValue: TestState())
        let storage = _ViewStateStorage(count: 1) { state.__initializeState(into: &$0) }
        state.__restoreState(storage: storage, index: 0)

        let binding = state.projectedValue.value

        binding.wrappedValue += 1

        #expect(state.wrappedValue.value == 43)
        #expect(binding.wrappedValue == 43)
    }

    @Test
    func tracksReactiveChanges() {
        var state1 = State(wrappedValue: 42)
        var state2 = State(wrappedValue: "no change")
        nonisolated(unsafe) var hasChanged = false

        let storage = _ViewStateStorage(count: 2) { values in
            state1.__initializeState(into: &values)
            state2.__initializeState(into: &values)
        }
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
        var state = State(wrappedValue: TestState())
        let storage = _ViewStateStorage(count: 1) { state.__initializeState(into: &$0) }
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
