import ElementaryUI

@View
struct AnimationsApp {
    @State var isVisible = false
    @State var isOffset = false

    var body: some View {
        button { "Toggle" }
            .onClick { _ in
                withAnimation(.bouncy) {
                    isVisible.toggle()
                    isOffset.toggle()
                }
            }

        div {
            if isVisible {
                span { "Hello" }
                    .transition(.fade, animation: .bouncy)
            }
        }.animateContainerLayout()

        p { "Scaled" }
            .scaleEffect(isOffset ? 1.5 : 1, anchor: .topLeading)
            .offset(x: isOffset ? 80 : 0, y: 0)
            .animation(.easeIn, value: isOffset)
    }
}

Application(AnimationsApp()).mount(in: "#app")
