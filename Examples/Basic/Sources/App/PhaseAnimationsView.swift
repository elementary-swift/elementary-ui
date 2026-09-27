import ElementaryUI

@View
struct PhaseAnimationsView {
    @State var phaseTrigger = 0

    var body: some View {
        div {
            h2 { "Phase animations" }
            div(.style(["display": "flex", "align-items": "center", "gap": "24px", "padding": "24px"])) {
                PhaseAnimator([false, true]) { highlighted in
                    Square(color: "purple")
                        .scaleEffect(highlighted ? 1.15 : 0.85)
                        .opacity(highlighted ? 1 : 0.5)
                } animation: { _ in
                    .easeInOut(duration: 0.8)
                }

                Square(color: "orange")
                    .phaseAnimator([0, 1, 2], trigger: phaseTrigger) { content, phase in
                        content
                            .offset(y: phase == 1 ? -30 : 0)
                            .scaleEffect(phase == 2 ? 1.4 : 1)
                    } animation: { _ in
                        .bouncy(duration: 0.6)
                    }

                button { "Trigger phases" }.onClick { phaseTrigger += 1 }
            }
            p { "Purple loops continuously. Click repeatedly to redirect the orange animation." }
        }
    }
}
