import BasicContainers
import JavaScriptKit

@JSFunction(from: .snippet("/JavaScript/custom-elements.js"))
func defineCustomElement(
    _ name: String,
    _ implementation: CustomElementBridge
) throws(JSException)

@JS
final class CustomElementBridge {
    let factory: (JSHTMLElement) throws(JSException) -> MountedCustomElement
    var elements = UniqueDictionary<JSHTMLElement, MountedCustomElement>()

    init(
        observedAttributes: [String],
        factory: @escaping (JSHTMLElement) throws(JSException) -> MountedCustomElement
    ) {
        self.observedAttributes = observedAttributes
        self.factory = factory
    }

    @JS
    var observedAttributes: [String]

    @JS
    func connect(element: JSHTMLElement) throws(JSException) {
        let existing = elements.insertValue(try factory(element), forKey: element)
        existing?.unmount()
    }

    @JS
    func disconnect(element: JSHTMLElement) {
        guard let mounted = elements.removeValue(forKey: element) else { return }
        mounted.unmount()
    }

    @JS
    func setAttribute(element: JSHTMLElement, name: String, value: String?) {
        elements.withValue(forKey: element) { $0.setAttribute(name: name, value: value) }
    }
}

@JSClass(jsName: "HTMLElement")
struct JSHTMLElement: Hashable {
    @JSGetter var shadowRoot: JSShadowRoot?
    @JSFunction func getAttribute(_ name: String) throws(JSException) -> String?
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
