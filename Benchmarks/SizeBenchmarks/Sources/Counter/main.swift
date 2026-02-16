import ElementaryUI

@View
struct CounterApp {
    @State var count = 0

    var body: some View {
        button { "Count: \(count)" }
            .onClick { _ in count += 1 }
    }
}

Application(CounterApp()).mount(in: "#app")
