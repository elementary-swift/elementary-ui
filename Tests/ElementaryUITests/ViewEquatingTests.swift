import ElementaryUI
import Reactivity
import Testing

@Suite
struct ViewEquatingTests {
    @Test
    func emptyViewsAreAlwaysEqual() {
        #expect(areEqual(EmptyView(), EmptyView()))
    }

    @Test
    func equatesSimplePropertiesOfView() {
        #expect(areEqual(SimpleView(text: "A", num: 42), SimpleView(text: "A", num: 42)))
        #expect(!areEqual(SimpleView(text: "A", num: 42), SimpleView(text: "A", num: 43)))
        #expect(!areEqual(SimpleView(text: "A", num: 42), SimpleView(text: "B", num: 42)))
    }

    @Test
    func equatesEquatableView() {
        #expect(areEqual(EquatableView(state: .init(num: 42)), EquatableView(state: .init(num: 42))))
        #expect(!areEqual(EquatableView(state: .init(num: 42)), EquatableView(state: .init(num: 43))))
    }

    @Test
    func ignoresStateAndEnvironment() {
        #expect(areEqual(ViewWithStuff(number: 42), ViewWithStuff(number: 42, state: 1)))
        #expect(!areEqual(ViewWithStuff(number: 42), ViewWithStuff(number: 43)))
    }

    @Test
    func comparesStateObjectsByReference() {
        let state = SomeState()
        let state2 = SomeState()

        #expect(areEqual(ViewWithState(state: state), ViewWithState(state: state)))
        #expect(!areEqual(ViewWithState(state: state), ViewWithState(state: state2)))
    }

    @Test
    func ignoresStateBindings() {
        let closureBinding = Binding(get: { 42 }, set: { _ in })
        @State var state = 42
        let storage = _ViewStateStorage(count: 1) { _state.__initializeState(into: &$0) }
        _state.__restoreState(storage: storage, index: 0)

        #expect(areEqual(ViewWithBinding(binding: $state), ViewWithBinding(binding: $state)))
        #expect(!areEqual(ViewWithBinding(binding: closureBinding), ViewWithBinding(binding: closureBinding)))
        #expect(!areEqual(ViewWithBinding(binding: closureBinding), ViewWithBinding(binding: $state)))
    }
}

private func areEqual<V: __FunctionView>(_ a: V, _ b: V) -> Bool {
    V.__areEqual(a: a, b: b)
}

@View
private struct EmptyView {
    var body: some View {
        "Hello"
    }
}

@View
struct SimpleView {
    var text: String
    let num: Int

    var body: some View {
        text
    }
}

@View
private struct EquatableView: Equatable {
    struct State {
        var num: Int
    }

    let state: State

    var body: some View {}

    static func == (lhs: EquatableView, rhs: EquatableView) -> Bool {
        lhs.state.num == rhs.state.num
    }
}

@View
private struct ViewWithStuff {
    let number: Int
    @Environment(#Key(\.tracker)) var tracker
    @State var state: Int = 0

    var body: some View {
    }
}

@View
private struct ViewWithState {
    var state: SomeState

    var body: some View {
    }
}

@View
private struct ViewWithBinding {
    @Binding var binding: Int
}

@Reactive
private final class SomeState {
    var num: Int = 0
}
