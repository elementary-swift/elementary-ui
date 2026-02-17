import ElementaryUI
import Reactivity

extension EnvironmentValues {
    @Entry var myText: String = ""
}

@View
struct AppView {
    @State var counters: [Int] = [1]
    @State var nextCounterName = 1
    @State var data = SomeData()
    @State var bindingViewCount = 1

    var body: some View {
        div {
            for _ in 0..<bindingViewCount {
                BindingsView()
                    .transition(.fade, animation: .bouncy)
            }
            button { "Add bindings view" }
                .onClick { _ in
                    bindingViewCount += 1
                }
            button { "Remove bindings view" }
                .onClick { _ in
                    guard bindingViewCount > 0 else { return }
                    bindingViewCount -= 1
                }
        }
        div {
            hr()
            ToggleTestView()
            hr()
        }

        div {
            hr()
            FocusDemoView()
            hr()
        }

        // TODE: replaceChildren does not keep animations and similar going....
        // if counters.count > 1 {
        //     span {}.attributes(.style(["display": "none"]))
        // }

        p {
            switch counters.count {
            case 0:
                "No counters"
            case 1:
                "One counter"
            default:
                "Multiple counters"
            }
        }
        .attributes(
            .style([
                "transition": "all 1s",
                "color": counters.count > 1 ? "red" : "blue",
            ])
        )

        div {
            hr()
            div {
                button { "Add counter" }
                    .onClick { _ in
                        nextCounterName += 1
                        withAnimation {
                            counters.append(nextCounterName)
                        }
                    }

                button { "Shuffle" }
                    .onClick { _ in
                        withAnimation {
                            counters.shuffle()
                        }
                    }
            }
            div(.style(["display": "flex", "flex-direction": "column", "border": "1px solid red"])) {
                ForEach(counters, key: { String($0) }) { counter in
                    div {
                        h3 { "Counter \(counter)" }
                        Counter(count: counter)
                        br()
                        button { "Remove counter" }
                            .onClick { _ in
                                withAnimation(.linear(duration: 2)) {
                                    counters.removeAll { $0 == counter }
                                }
                            }
                        hr()
                    }.transition(.fade)
                }
            }.animateContainerLayout()
        }

        div {
            FilterDemoView()
            hr()
            AnimationsView()
            hr()
            TextField(value: #Binding(data.name))

            div {
                p { "Via Binding: \(data.name)" }
                p { TestValueView() }
                p { TestObjectView() }
            }
            .environment(#Key(\.myText), data.name)
            .environment(data)
        }
        .onChange(of: bindingViewCount) { oldValue, newValue in
            print("bindingViewCount changed to \(oldValue) -> \(newValue)")
        }
        .onChange(of: bindingViewCount) {
            if bindingViewCount > 5 {
                data.name = "Binding View Count > 5"
            }
        }
    }
}

@View
struct Counter {
    @State var count: Int = 0

    var body: some View {
        div {
            button { "-" }
                .onClick { _ in count -= 1 }
            span { " \(count) " }
            button { "+" }
                .onClick { _ in count += 1 }

        }
        .onAppear {
            print("Counter with count \(count) mounted")
        }
        .onDisappear {
            print("Counter with count \(count) unmounted")
        }
    }
}

@View
struct TextField {
    @Binding<String> var value: String

    var body: some View {
        input(.type(.text))
            .bindValue($value)
    }
}

@Reactive
final class SomeData {
    var name: String = ""
    var age: Int = 0
}

@View
struct TestValueView {
    @Environment(#Key(\.myText)) var key

    var body: some View {
        span { "Via environment value: \(key)" }
    }
}

@View
struct TestObjectView {
    @Environment(SomeData.self) var data: SomeData
    @Environment(SomeData.self) var optionalData: SomeData?

    var body: some View {
        span { "Via environment object: \(data.name)" }
        br()
        span { "Via optional environment object: \(optionalData?.name ?? "")" }
    }
}

@View
struct ToggleTestView {
    @State var isVisible: Bool = false

    var body: some View {
        div(.style(["display": "flex", "flex-direction": "column", "border": "1px solid blue"])) {
            button { "Toggle" }
                .onClick {
                    withAnimation(.snappy(duration: 2)) {
                        isVisible.toggle()
                    }
                }

            span { "start " }
            if isVisible {
                span { "middle " }
                    .transition(.fade)
            }

            span { "end" }

        }.animateContainerLayout()
    }
}
