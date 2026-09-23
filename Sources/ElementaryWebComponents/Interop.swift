import JavaScriptKit

@JSClass(jsName: "HTMLElement")
struct JSHTMLElement: Hashable {
    @JSGetter var shadowRoot: JSShadowRoot?
    @JSFunction func attachShadow(_ options: JSShadowRootInit) throws(JSException) -> JSShadowRoot

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.jsObject == rhs.jsObject
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(jsObject)
    }
}

@JSClass(jsName: "ShadowRoot")
struct JSShadowRoot {
    @JSSetter func setAdoptedStyleSheets(_ styleSheets: [JSCSSStyleSheet]) throws(JSException)
}

@JS
struct JSShadowRootInit {
    var mode: String
}

@JSClass(jsName: "CSSStyleSheet", from: .global)
struct JSCSSStyleSheet {
    @JSFunction init() throws(JSException)
    @JSFunction func replaceSync(_ css: String) throws(JSException)
}
