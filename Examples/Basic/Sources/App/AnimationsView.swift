import ElementaryUI
import _ElementaryMath

@View
struct AnimationsView {
    @State var angle: Double = 0
    @State var isBallFading: Bool = false
    @State var isOffset: Bool = false
    @State var isRotated: Bool = false

    var body: some View {

        div {
            AnimatedView(angle: angle, isBallFading: isBallFading)
            div(.style(["display": "flex", "flex-direction": "row", "gap": "10px"])) {
                button { "Animate" }
                    .onClick { _ in
                        withAnimation(.bouncy) {
                            angle += 1
                            isBallFading.toggle()
                        }
                    }
                Square(color: "green")
                    .scaleEffect(angle, anchor: .leading)
                Square(color: "blue")
                    .rotationEffect(.degrees(0))
                    .rotationEffect(.radians(angle), anchor: .topLeading)
                Square(color: "red")
                    .rotationEffect(.degrees(isRotated ? 360 : 0))
                    .offset(x: isOffset ? 100 : 0)
                    .onClick { _ in
                        withAnimation(.bouncy(duration: 3)) {
                            isOffset.toggle()
                        }
                        withAnimation(.easeIn(duration: 1).delay(1)) {
                            isRotated.toggle()
                        }
                    }
            }
        }
    }
}

@View
struct AnimatedView {
    var angle: Double
    var isBallFading: Bool

    let size = 100.0
    var x: Double { size * (1 - cos(angle)) }
    var y: Double { size * (1 - sin(angle)) }

    var body: some View {
        p { "Angle: \(angle) x: \(x) y: \(y)" }
        div {
            Ball()
                .attributes(
                    .style([
                        "transform": "translate(\(x)px, \(y)px)",
                        "position": "relative",
                    ])
                )
                .opacity(isBallFading ? 0.1 : 1)
        }.attributes(
            .style([
                "height": "\(2 * size + 10)px",
                "width": "\(2 * size + 10)px",
                "position": "relative",
            ])
        )
    }
}

@View
struct Square {
    var color: String

    var body: some View {
        span {}
            .attributes(
                .style([
                    "background": color,
                    "height": "20px",
                    "width": "20px",
                ])
            )
    }
}

extension AnimatedView: Animatable {
    var animatableValue: Double {
        get { angle }
        set { angle = newValue }
    }
}

@View
struct Ball {
    var body: some HTML<HTMLTag.span> & View {
        span {}
            .attributes(
                .style([
                    "background": "red",
                    "height": "10px",
                    "width": "10px",
                    "border-radius": "50%",
                    "display": "block",
                ])
            )
    }
}

@View
struct FilterDemoView {
    @State var blurAmount: Double = 0
    @State var saturationAmount: Double = 1
    @State var brightnessAmount: Double = 1

    var body: some View {
        div {
            h3 { "Filter Stacked Animation Test" }
            p { "Click buttons to toggle each filter independently on the same box" }

            div(.style(["display": "flex", "flex-direction": "row", "gap": "20px", "align-items": "flex-start"])) {
                // The test box with all stacked filters
                div(.style(["display": "flex", "flex-direction": "column", "align-items": "center", "gap": "10px"])) {
                    FilterBox(color: "purple", label: "Stacked Filters")
                        .blur(radius: blurAmount)
                        .saturation(saturationAmount)
                        .brightness(brightnessAmount)

                    p(.style(["font-size": "11px", "margin": "0"])) {
                        "blur: \(Int(blurAmount)) sat: \(saturationAmount) bright: \(brightnessAmount)"
                    }
                }

                // Control buttons
                div(.style(["display": "flex", "flex-direction": "column", "gap": "8px"])) {
                    button { "Toggle Blur" }
                        .onClick { _ in
                            withAnimation(.easeInOut(duration: 1)) {
                                blurAmount = blurAmount > 0 ? 0 : 8
                            }
                        }

                    button { "Toggle Saturation" }
                        .onClick { _ in
                            withAnimation(.easeInOut(duration: 1)) {
                                saturationAmount = saturationAmount < 1 ? 1 : 0.2
                            }
                        }

                    button { "Toggle Brightness" }
                        .onClick { _ in
                            withAnimation(.easeInOut(duration: 1)) {
                                brightnessAmount = brightnessAmount > 1 ? 1 : 1.5
                            }
                        }

                    button { "Reset All" }
                        .onClick { _ in
                            withAnimation(.easeInOut(duration: 0.5)) {
                                blurAmount = 0
                                saturationAmount = 1
                                brightnessAmount = 1
                            }
                        }
                }
            }
        }
    }
}

@View
struct FilterBox {
    var color: String
    var label: String

    var body: some View {
        div(
            .style([
                "background": color,
                "width": "100px",
                "height": "100px",
                "display": "flex",
                "align-items": "center",
                "justify-content": "center",
                "color": "white",
                "font-size": "12px",
                "text-align": "center",
                "cursor": "pointer",
                "border-radius": "8px",
            ])
        ) {
            span { label }
        }
    }
}
