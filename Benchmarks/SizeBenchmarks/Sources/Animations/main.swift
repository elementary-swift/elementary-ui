import ElementaryUI

@View
struct AnimationsApp {
    @State var isVisible = false

    var body: some View {
        button { "Toggle" }
            .onClick { _ in
                withAnimation {
                    isVisible.toggle()
                }
            }
        if isVisible {
            div { "Animated!" }
                .transition(.fade, animation: .bouncy)
        }
    }
}

Application(AnimationsApp()).mount(in: "#app")
