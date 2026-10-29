import ElementaryUI
import Reactivity
import Testing

@Suite
struct ServerRenderingTests {
    // MARK: composition

    @Test
    func rendersSVGViews() {
        #expect(
            SVG.svg {
                Checkmark()
            }.render() == #"<svg><path d="M20 6 9 17l-5-5" /></svg>"#
        )
    }

    @Test
    func rendersForEachWithoutKeys() {
        #expect(
            ul {
                ForEach([1, 2, 3], id: { $0 }) { number in
                    li { "\(number)" }
                }
                ForEach([Item(id: 4)]) { item in
                    li { "\(item.id)" }
                }
            }.render() == "<ul><li>1</li><li>2</li><li>3</li><li>4</li></ul>"
        )
    }

    @Test
    func rendersKeyedViews() {
        #expect(p { "a" }.id("k").render() == "<p>a</p>")
    }

    @Test
    func rendersComposedViews() {
        #expect(Outer().render() == "<section><h1>Title</h1><p>Child 1</p><p>Child 2</p></section>")
    }

    @Test
    func rendersInitialState() {
        #expect(Counter().render() == "<div><p>Count: 5</p><button>+</button></div>")
    }

    @Test
    func rendersBindingsToState() {
        #expect(
            Form().render()
                == #"<div><input type="text" value="hello"><input type="number" value="3"><input type="checkbox" checked><p>hello</p></div>"#
        )
    }

    @Test
    func readsReactiveObjectsWithoutSubscribing() {
        let model = Model()
        #expect(ModelView(model: model).render() == "<p>42</p>")
    }

    // MARK: environment

    @Test
    func rendersEnvironmentDefaults() {
        #expect(EnvironmentReader().render() == "<p>default</p>")
    }

    @Test
    func rendersEnvironmentValuesScopedToTheirSubtree() {
        #expect(
            div {
                EnvironmentReader()
                div {
                    EnvironmentReader()
                    EnvironmentReader().environment(#Key(\.serverTestValue), "inner")
                    EnvironmentReader()
                }
                .environment(#Key(\.serverTestValue), "outer")
                EnvironmentReader()
            }.render()
                == "<div><p>default</p><div><p>outer</p><p>inner</p><p>outer</p></div><p>default</p></div>"
        )
    }

    @Test
    func rendersReactiveObjectsFromEnvironment() {
        #expect(EnvironmentModelReader().environment(Model()).render() == "<p>42</p>")
    }

    // MARK: modifiers that are dropped on the server

    @Test
    func dropsEventHandlersAndLifecycle() {
        let calls = CallCounter()
        let html = button { "Tap" }
            .onClick { calls.count += 1 }
            .onAppear { calls.count += 1 }
            .onDisappear { calls.count += 1 }
            .task { calls.count += 1 }
            .onChange(of: 1, initial: true) { calls.count += 1 }
            .render()

        #expect(html == "<button>Tap</button>")
        #expect(calls.count == 0)
    }

    @Test
    func dropsFocus() {
        #expect(FocusView().render() == "<input>")
    }

    @Test
    func dropsAnimationsAndTransitions() {
        #expect(
            div { "a" }
                .animation(.default, value: 1)
                .transaction(value: 1) { $0.animation = nil }
                .animateContainerLayout()
                .transition(.fade)
                .render() == "<div>a</div>"
        )
    }

    @Test
    func dropsStyleModifiers() {
        // NOTE: style modifiers are not rendered on the server yet
        #expect(div { "a" }.opacity(0.5).render() == "<div>a</div>")
    }

    @Test
    func rendersFirstPhaseOfPhaseAnimators() {
        #expect(
            PhaseAnimator([1, 2, 3]) { phase in
                p { "phase \(phase)" }
            }.render() == "<p>phase 1</p>"
        )

        #expect(
            p { "content" }
                .phaseAnimator([false, true]) { content, phase in
                    div(.class(phase ? "on" : "off")) { content }
                }.render() == #"<div class="off"><p>content</p></div>"#
        )
    }

    @Test
    func rendersAnimatableViewsAtTheirTargetValue() {
        #expect(AnimatedNumber(animatableValue: 2).render() == "<p>2.0</p>")
    }

    // MARK: interop

    @Test
    func rendersInsideElementaryHTML() {
        #expect(
            Page().render()
                == #"<main><h1>Page</h1><div><p>Count: 5</p><button>+</button></div><p>default</p></main>"#
        )
    }

    @Test
    func rendersAsync() async throws {
        #expect(try await Page().renderAsync() == Page().render())
    }

    @Test
    func rendersEnvironmentValuesAsync() async throws {
        let html = try await div {
            EnvironmentReader().environment(#Key(\.serverTestValue), "async")
            EnvironmentReader()
        }.renderAsync()
        #expect(html == "<div><p>async</p><p>default</p></div>")
    }

    @Test
    func rendersFormatted() {
        #expect(
            Page().renderFormatted()
                == """
                <main>
                  <h1>Page</h1>
                  <div>
                    <p>Count: 5</p>
                    <button>+</button>
                  </div>
                  <p>default</p>
                </main>
                """
        )
    }
}

// MARK: - Test views

private struct Item: Identifiable {
    var id: Int
}

private final class CallCounter {
    var count = 0
}

@Reactive
private final class Model {
    var number = 42
}

extension EnvironmentValues {
    @Entry fileprivate var serverTestValue = "default"
}

@View
private struct Checkmark: SVGView {
    var body: some SVGView {
        SVG.path(.d("M20 6 9 17l-5-5"))
    }
}

@View
private struct Child {
    var number: Int

    var body: some View {
        p { "Child \(number)" }
    }
}

@View
private struct Outer {
    var body: some View {
        section {
            h1 { "Title" }
            Child(number: 1)
            Child(number: 2)
        }
    }
}

@View
private struct Counter {
    @State var count = 5

    var body: some View {
        div {
            p { "Count: \(count)" }
            button { "+" }
                .onClick { count += 1 }
        }
    }
}

@View
private struct Label {
    @Binding var text: String

    var body: some View {
        p { text }
    }
}

@View
private struct Form {
    @State var text = "hello"
    @State var number: Double? = 3
    @State var isOn = true

    var body: some View {
        div {
            input(.type(.text)).bindValue($text)
            input(.type(.number)).bindValue($number)
            input(.type(.checkbox)).bindChecked($isOn)
            Label(text: $text)
        }
    }
}

@View
private struct ModelView {
    var model: Model

    var body: some View {
        p { "\(model.number)" }
    }
}

@View
private struct EnvironmentReader {
    @Environment(#Key(\.serverTestValue)) var value

    var body: some View {
        p { value }
    }
}

@View
private struct EnvironmentModelReader {
    @Environment(Model.self) var model

    var body: some View {
        p { "\(model.number)" }
    }
}

@View
private struct FocusView {
    @FocusState var isFocused: Bool

    var body: some View {
        input().focused($isFocused)
    }
}

@View
private struct AnimatedNumber: Animatable {
    var animatableValue: Double

    var body: some View {
        p { "\(animatableValue)" }
    }
}

private struct Page: HTML {
    var body: some HTML {
        main {
            h1 { "Page" }
            Counter()
            EnvironmentReader()
        }
    }
}
