import Reactivity
import Testing

@testable import ElementaryUI

struct EnvironmentInvalidationTests {
    @Test
    func rerunsReadersOfValuesWithoutEquality() {
        let model = Model()

        let calls = trackUpdating {
            PlainProvider(model: model)
        } toggle: {
            model.outer += 1
        }

        #expect(calls == ["PlainProvider", "plain: 1"])
    }

    @Test
    func innerModifierShadowsOuterChanges() {
        let model = Model()

        let calls = trackUpdating {
            NestedProviders(model: model)
        } toggle: {
            model.outer += 1
        }

        #expect(calls == ["Nested"])
    }
}

@Reactive
private final class Model {
    var outer = 0
    var inner = 0
}

/// Has no equality, so every new value counts as a change.
private struct Plain {
    let number: Int
}

extension EnvironmentValues {
    @Entry fileprivate var invalidationValue: Int = 0
    @Entry fileprivate var plainValue: Plain = Plain(number: 0)
}

@View
private struct PlainProvider {
    let model: Model

    var body: some View {
        Track(name: "PlainProvider") {
            PlainReader()
        }
        .environment(#Key(\.plainValue), Plain(number: model.outer))
    }
}

@View
private struct PlainReader {
    @Environment(#Key(\.plainValue)) var plain

    var body: some View {
        Track(name: "plain: \(plain.number)") {}
    }
}

@View
private struct ValueReader {
    @Environment(#Key(\.invalidationValue)) var value

    var body: some View {
        Track(name: "value: \(value)") {}
    }
}

@View
private struct NestedProviders {
    let model: Model

    var body: some View {
        Track(name: "Nested") {
            ValueReader()
                .environment(#Key(\.invalidationValue), model.inner)
        }
        .environment(#Key(\.invalidationValue), model.outer)
    }
}
