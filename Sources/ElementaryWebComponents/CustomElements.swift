import JavaScriptKit

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
    }

    /// Registers a custom HTML element implemented by `Element`.
    ///
    /// A new `Element` is created for each host. When `shadow` is `nil`, the view is appended to the host's light DOM, after any existing children. Otherwise the view is mounted in the shadow root described by `shadow`.
    ///
    /// Custom element names must contain a hyphen. An invalid name or a duplicate registration throws ``JSException``.
    public static func define<Element: CustomElement>(
        _ name: String,
        _: Element.Type,
        shadow: ShadowRootOptions? = nil
    ) throws(JSException) {
        try defineCustomElement(
            name,
            CustomElementBridge(
                name: name,
                shadow: shadow,
                factory: Element.init
            )
        )
    }
}
