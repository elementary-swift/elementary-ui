import JavaScriptKit

/// An immutable constructable stylesheet that can be shared by multiple shadow roots.
public struct CustomElementStyleSheet {
    let jsStyleSheet: JSCSSStyleSheet

    public init(_ css: String) throws(JSException) {
        let styleSheet = try JSCSSStyleSheet()
        try styleSheet.replaceSync(css)
        jsStyleSheet = styleSheet
    }
}
