import ElementaryUIMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class CustomElementMacroTests: XCTestCase {
    private let macros: [String: Macro.Type] = [
        "CustomElement": CustomElementMacro.self
    ]

    func testSuppliesViewAndCustomElementBehavior() {
        assertMacroExpansion(
            """
            @CustomElement
            struct Greeting {
                @Attribute var title = "Hello"
                var body: some View { title }
            }
            """,
            expandedSource: """
                struct Greeting {
                    @Attribute var title = "Hello"
                    @ContentBuilder
                    var body: some View { title }

                    static var observedAttributes: [String] {
                        ["title"]
                    }

                    func setAttribute(name: String, value: String?) -> Bool {
                        switch name {
                        case "title":
                            guard let value else {
                                self._title.wrappedValue = "Hello"
                                return true
                            }
                            return self._title._setAttributeValue(value)
                        default:
                            return false
                        }
                    }
                }

                extension Greeting: CustomElement {
                }
                """,
            macros: macros
        )
    }

    func testRejectsNonStructDeclarations() {
        assertMacroExpansion(
            """
            @CustomElement
            final class InvalidElement {
                var body: some View { "invalid" }
            }
            """,
            expandedSource: """
                final class InvalidElement {
                    var body: some View { "invalid" }
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@CustomElement' can only be applied to a struct",
                    line: 1,
                    column: 1
                )
            ],
            macros: macros
        )
    }

    func testRejectsInvalidAttributeDeclarations() {
        assertMacroExpansion(
            """
            @CustomElement
            struct InvalidAttributes {
                @Attribute let immutable = 1
                @Attribute static var shared = 1
                @Attribute var missing: Int
                @Attribute("UPPER") var invalidName = 1
                @Attribute("same") var first = 1
                @Attribute("same") var second = 2
            }
            """,
            expandedSource: """
                struct InvalidAttributes {
                    @Attribute let immutable = 1
                    @Attribute static var shared = 1
                    @Attribute var missing: Int
                    @Attribute("UPPER") var invalidName = 1
                    @Attribute("same") var first = 1
                    @Attribute("same") var second = 2
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@Attribute' requires a stored instance variable",
                    line: 3,
                    column: 5
                ),
                DiagnosticSpec(
                    message: "'@Attribute' requires a stored instance variable",
                    line: 4,
                    column: 5
                ),
                DiagnosticSpec(
                    message: "non-optional '@Attribute' property 'missing' requires a default value",
                    line: 5,
                    column: 5
                ),
                DiagnosticSpec(
                    message: "'UPPER' is not a valid lowercase HTML attribute name",
                    line: 6,
                    column: 5
                ),
                DiagnosticSpec(
                    message: "attribute name 'same' is already used by 'first'",
                    line: 8,
                    column: 5
                ),
            ],
            macros: macros
        )
    }

    func testRejectsSVGBody() {
        assertMacroExpansion(
            """
            @CustomElement
            struct SVGElement {
                var body: some SVGView { circle() }
            }
            """,
            expandedSource: """
                struct SVGElement {
                    var body: some SVGView { circle() }
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "a custom element body must be an HTML View, not an SVGView",
                    line: 1,
                    column: 1
                )
            ],
            macros: macros
        )
    }
}
