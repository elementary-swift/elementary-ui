import ElementaryUI
import Testing

@Suite
struct ForEachRenderingTests {
    @Test
    func rendersRange() {
        let html = ul {
            ForEach(0..<3) { index in
                li { "\(index)" }
            }
        }

        #expect(html.render() == "<ul><li>0</li><li>1</li><li>2</li></ul>")
    }

    @Test
    func rendersAsync() async throws {
        let html = ul {
            ForEach(0..<2) { index in
                li { "\(index)" }
            }
        }

        #expect(try await html.renderAsync() == "<ul><li>0</li><li>1</li></ul>")
    }

    @Test
    func rendersSVGContent() {
        let html = SVG.svg {
            ForEach(0..<2) { index in
                SVG.circle(.cx(index == 0 ? 0 : 1))
            }
        }

        #expect(html.render() == #"<svg><circle cx="0" /><circle cx="1" /></svg>"#)
    }
}
