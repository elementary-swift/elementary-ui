/// A selector for targeting DOM elements when mounting an ElementaryUI application.
///
/// `DOMElementSelector` provides a type-safe way to specify which DOM element should serve as
/// the mounting point for your application. You can target either the document body or use
/// CSS selectors to target specific elements.
///
/// ## Using CSS Selectors
///
/// Target specific elements using CSS selector syntax:
/// ```swift
/// app.mount(in: "#app")           // Element with id="app"
/// app.mount(in: ".container")     // First element with class="container"
/// app.mount(in: "main")           // First <main> element
/// app.mount(in: "[data-app]")     // Element with data-app attribute
/// ```
public struct DOMElementSelector: Sendable, ExpressibleByStringLiteral {
    enum Value: Sendable {
        case body
        case cssSelector(String)
    }

    let value: Value

    init(value: Value) {
        self.value = value
    }

    /// Creates a selector from a CSS selector string literal.
    ///
    /// This allows you to use string literals directly as selectors:
    /// ```swift
    /// app.mount(in: "#app")
    /// ```
    ///
    /// - Parameter value: A CSS selector string (e.g., `"#app"`, `".container"`, `"main"`).
    public init(stringLiteral value: String) {
        self.init(value: .cssSelector(value))
    }

    /// A selector targeting the document body element (`<body>`).
    ///
    /// Use this to mount your application directly into the document body:
    /// ```swift
    /// app.mount(in: .body)
    /// ```
    public static var body: DOMElementSelector {
        DOMElementSelector(value: .body)
    }
}

internal extension DOMElementSelector {
    func findDOMNode(dom: DOMInteractor) -> DOM.Node? {
        switch value {
        case .body:
            // TODO: this isn't so great....
            return GlobalDocument.body
        case let .cssSelector(selector):
            return dom.querySelector(selector)
        }
    }
}
