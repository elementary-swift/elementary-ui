import JavaScriptKit

/// Registers ElementaryUI views as browser custom elements.
public enum CustomElements {
    /// Options for a custom element's shadow root and stylesheets.
    public struct ShadowRootOptions {
        /// The shadow root's access mode.
        public enum Mode: String {
            /// Makes the root accessible through `element.shadowRoot`.
            case open
        }

        /// The shadow root's access mode.
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
    /// Each host gets its own `Element` instance. When `shadow` is `nil`, the view is appended
    /// after the host's existing children. Otherwise, it mounts in the specified shadow root.
    ///
    /// The name must be a valid custom element name, including a hyphen. Invalid names and
    /// duplicate registrations throw `JSException`. During Vite HMR, duplicate registrations
    /// update the existing element definition instead.
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
