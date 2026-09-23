import JavaScriptKit

/// Configures where ElementaryUI mounts a custom element's view.
public struct CustomElementShadowDOM {
    enum Mode: String {
        case open
        case none
    }

    let mode: Mode
    let styleSheets: [CustomElementStyleSheet]

    /// Mount into an inspectable open shadow root. This is the default.
    public static let open = Self(mode: .open, styleSheets: [])

    /// Mount into an inspectable open shadow root with shared constructable stylesheets.
    public static func open(styleSheets: [CustomElementStyleSheet]) -> Self {
        Self(mode: .open, styleSheets: styleSheets)
    }

    /// Mount directly into the host, after any existing light-DOM children.
    public static let none = Self(mode: .none, styleSheets: [])

    fileprivate var bridgeValue: String { mode.rawValue }
}

/// An error raised while registering a custom element with the browser.
public struct CustomElementRegistrationError: Error, Sendable, CustomStringConvertible {
    public let elementName: String
    public let message: String

    public var description: String {
        "Could not define custom element <\(elementName)>: \(message)"
    }

    init(elementName: String, message: String) {
        self.elementName = elementName
        self.message = message
    }
}

/// Browser custom-element registration APIs.
public enum CustomElements {
    /// Defines an autonomous custom element backed by a fresh ElementaryUI view per host.
    ///
    /// The browser requires custom-element names to contain a hyphen. Invalid names and
    /// duplicate definitions throw ``CustomElementRegistrationError``.
    public static func define<Element: CustomElement>(
        _ name: String,
        shadowDOM: CustomElementShadowDOM = .open,
        factory: @escaping () -> Element
    ) throws(CustomElementRegistrationError) {
        let implementation = CustomElementImplementation(
            name: name,
            shadowDOM: shadowDOM,
            factory: factory
        )

        do {
            try defineCustomElement(
                name,
                shadowDOM.bridgeValue,
                Element.observedAttributes,
                implementation
            )
        } catch let error {
            throw CustomElementRegistrationError(elementName: name, message: error.description)
        }
    }
}
