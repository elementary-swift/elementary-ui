import ElementaryUI

// Each tile draws a dashed outline where the shape starts and the transformed shape on
// top, so the anchor is visible rather than inferred. SVG resolves transform-origin
// against the viewBox rather than the element, so without the fix these pivot on the
// tile's top-left corner instead of the shape.
@View
struct SVGTransformsView {
    @State var isTransformed = false

    var angle: Angle { .degrees(isTransformed ? 45 : 0) }
    var scale: Double { isTransformed ? 1.6 : 1 }

    var body: some View {
        div {
            h3 { "SVG transforms" }

            div(.style(["display": "flex", "gap": "16px", "flex-wrap": "wrap"])) {
                tile("rotate, centre") {
                    SVG.rect(.x(25), .y(25), .width(30), .height(30), .fill("#e3562a"))
                        .rotationEffect(angle)
                }
                tile("rotate, topLeading") {
                    SVG.rect(.x(25), .y(25), .width(30), .height(30), .fill("#2a7ae3"))
                        .rotationEffect(angle, anchor: .topLeading)
                }
                tile("scale, centre") {
                    SVG.rect(.x(25), .y(25), .width(30), .height(30), .fill("#2aa74a"))
                        .scaleEffect(scale)
                }
                tile("scale x only") {
                    SVG.rect(.x(25), .y(25), .width(30), .height(30), .fill("#8a2ae3"))
                        .scaleEffect(x: scale, y: 1)
                }
                tile("rotate a group") {
                    SVG.g {
                        SVG.rect(.x(25), .y(25), .width(30), .height(12), .fill("#e3a72a"))
                        SVG.rect(.x(25), .y(43), .width(30), .height(12), .fill("#e3a72a"))
                    }
                    .rotationEffect(angle)
                }
                tile("offset (unaffected)") {
                    SVG.rect(.x(25), .y(25), .width(30), .height(30), .fill("#777"))
                        .offset(x: isTransformed ? 15 : 0, y: 0)
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
}

@View
struct SVGTransformTile<Content: SVGView> {
    let label: String
    let content: Content

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

func tile(_ label: String, @ContentBuilder content: () -> some SVGView) -> some View {
    SVGTransformTile(label: label, content: content())
}
