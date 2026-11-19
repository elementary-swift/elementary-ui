import ElementaryUI

@View
struct SVGTransformsView {
    @State var isTransformed = false

    var angle: Angle { .degrees(isTransformed ? 45 : 0) }
    var scale: Double { isTransformed ? 1.6 : 1 }

    var body: some View {
        div {
            h3 { "SVG transforms" }

            div(.style(["display": "flex", "gap": "16px", "flex-wrap": "wrap"])) {
                SVGTransformTile(label: "rotate, center") {
                    square("#e3562a").rotationEffect(angle)
                }
                SVGTransformTile(label: "rotate, topLeading") {
                    square("#2a7ae3").rotationEffect(angle, anchor: .topLeading)
                }
                SVGTransformTile(label: "scale, center") {
                    square("#2aa74a").scaleEffect(scale)
                }
                SVGTransformTile(label: "scale, bottomTrailing") {
                    square("#2aa7a7").scaleEffect(scale, anchor: .bottomTrailing)
                }
                SVGTransformTile(label: "scale x only") {
                    square("#8a2ae3").scaleEffect(x: scale, y: 1)
                }
                SVGTransformTile(label: "rotate + scale") {
                    square("#e32a8a").rotationEffect(angle).scaleEffect(scale)
                }
                SVGTransformTile(label: "rotate a group") {
                    SVG.g {
                        SVG.rect(.x(25), .y(25), .width(30), .height(12), .fill("#e3a72a"))
                        SVG.rect(.x(25), .y(43), .width(30), .height(12), .fill("#e3a72a"))
                    }
                    .rotationEffect(angle)
                }
                SVGTransformTile(label: "offset") {
                    square("#777").offset(x: isTransformed ? 15 : 0, y: 0)
                }
            }

            button { isTransformed ? "Reset" : "Transform" }
                .onClick { _ in
                    withAnimation(.bouncy) {
                        isTransformed.toggle()
                    }
                }
        }
    }

    private func square(_ fill: SVGAttributeValue.Paint) -> some SVGView {
        SVG.rect(.x(25), .y(25), .width(30), .height(30), .fill(fill))
    }
}

@View
struct SVGTransformTile<Content: SVGView> {
    let label: String
    let content: Content

    init(label: String, @ContentBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        div(.style(["display": "flex", "flex-direction": "column", "gap": "4px"])) {
            SVG.svg(.width(80), .height(80), .viewBox(0, 0, 80, 80), .style(["border": "1px solid #ccc"])) {
                SVG.rect(
                    .x(25),
                    .y(25),
                    .width(30),
                    .height(30),
                    .fill("none"),
                    .stroke("#bbb"),
                    .strokeDasharray("3 3")
                )
                content
            }
            small { label }
        }
    }
}
