import JavaScriptKit

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
    /// Where a custom element's view is mounted, and which constructable stylesheets its shadow root adopts.
    public struct ShadowRootOptions {
        /// Shadow root mode passed to `attachShadow`.
        public enum Mode: String {
            /// The page can reach the root through `element.shadowRoot`.
            case open
        }

        /// How the shadow root is attached.
        public let mode: Mode

        /// Constructable stylesheets adopted by the shadow root, in order.
        public let styleSheets: [CustomElementStyleSheet]

        /// An open shadow root with no adopted stylesheets.
        public static let open = Self(mode: .open, styleSheets: [])

        /// An open shadow root that adopts `styleSheets`.
        public static func open(styleSheets: [CustomElementStyleSheet]) -> Self {
            Self(mode: .open, styleSheets: styleSheets)
        }

        fileprivate var bridgeValue: String { mode.rawValue }
    }

    /// Defines an autonomous custom element backed by a fresh `Element()` per host.
    ///
    /// Pass `shadow` to mount into a shadow root. The default mounts into the host, after any
    /// existing light-DOM children.
    ///
    /// The browser requires custom-element names to contain a hyphen. Invalid names and
    /// duplicate definitions throw ``CustomElementRegistrationError``.
    public static func define<Element: CustomElement>(
        _ name: String,
        _: Element.Type,
        shadow: ShadowRootOptions? = nil
    ) throws(CustomElementRegistrationError) {
        let implementation = CustomElementImplementation(
            name: name,
            shadow: shadow,
            factory: { Element() }
        )

        do {
            try defineCustomElement(
                name,
                shadow?.bridgeValue ?? "none",
                Element.observedAttributes,
                implementation
            )
        } catch let error {
            throw CustomElementRegistrationError(elementName: name, message: error.description)
        }
    }
}
