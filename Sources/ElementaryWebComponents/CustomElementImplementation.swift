import BasicContainers
import ElementaryUI
import JavaScriptKit
import Reactivity

public struct _CustomElementHostContext: ~Copyable {
    private var attributes: [PropertyID: any AnyAttributeBox] = [:]
    private let registrar = ReactivityRegistrar()

    public mutating func linkAttribute(_ name: String, _ attribute: Attribute<some CustomElementAttributeValue>) {
        let id = PropertyID(name)
        assert(attributes[id] == nil, "Attribute already added")

        attribute.box.attachReactivity(registrar, id: id)
        attributes[id] = attribute.box
    }

    func trySetAttribute(_ name: String, value: String?) -> Bool {
        let id = PropertyID(name)
        guard let box = attributes[id] else { return false }
        return box.trySetValue(value)
    }
}

extension _CustomElementHostContext {
    func setAttribute(_ name: String, value: String?, onElement elementName: String) {
        guard self.trySetAttribute(name, value: value) else {
            print("ELEMENTARY WARNING: invalid value for attribute '\(name)' on <\(elementName)>")
            return
        }
    }
}

/// One host element. Attribute values live in ``attributes``; the mount closure captures the
/// view, which already shares those slots.
private struct MountedCustomElement: ~Copyable {
    private let elementName: String
    private var application: MountedApplication
    private var context: _CustomElementHostContext

    // Generic initializers must be convenience on final classes for embedded Swift.
    init<Element: CustomElement>(
        elementName: String,
        host: JSHTMLElement,
        shadow: CustomElements.ShadowRootOptions?,
        factory: () -> Element
    ) throws(JSException) {
        self.elementName = elementName
        let mountTarget = try Self.resolveMountTarget(host: host, shadow: shadow)
        self.context = _CustomElementHostContext()

        let view = factory()
        view.__applyCustomElementContext(&self.context)

        for attributeName in Element.observedAttributes {
            guard let value = try? host.getAttribute(attributeName) else { continue }
            self.context.setAttribute(attributeName, value: value, onElement: self.elementName)
        }

        self.application = Application(view)._mount(in: mountTarget)
    }

    consuming func unmount() {
        application.unmount()
    }

    func setAttribute(name: String, value: String?) {
        context.setAttribute(name, value: value, onElement: self.elementName)
    }

    private static func resolveMountTarget(
        host: JSHTMLElement,
        shadow: CustomElements.ShadowRootOptions?
    ) throws(JSException) -> JSObject {
        guard let shadow else { return host.jsObject }
        switch shadow.mode {
        case .open:
            let shadowRoot: JSShadowRoot
            if let existingShadowRoot = try host.shadowRoot {
                shadowRoot = existingShadowRoot
            } else {
                shadowRoot = try host.attachShadow(JSShadowRootInit(mode: "open"))
            }
            try shadowRoot.setAdoptedStyleSheets(
                shadow.styleSheets.map { $0.jsStyleSheet }
            )
            return shadowRoot.jsObject
        }
    }
}

@JS
final class CustomElementClass {
    private let factory: (JSHTMLElement) throws(JSException) -> MountedCustomElement
    private var elements = UniqueDictionary<JSHTMLElement, MountedCustomElement>()

    private init(
        factory: @escaping (JSHTMLElement) throws(JSException) -> MountedCustomElement
    ) {
        self.factory = factory
    }

    convenience init<Element: CustomElement>(
        name: String,
        shadow: CustomElements.ShadowRootOptions?,
        factory: @escaping () -> Element
    ) {
        self.init { (host: JSHTMLElement) throws(JSException) -> MountedCustomElement in
            try MountedCustomElement(
                elementName: name,
                host: host,
                shadow: shadow,
                factory: factory
            )
        }
    }

    @JS
    func connect(element: JSHTMLElement) throws(JSException) {
        let existing = elements.insertValue(try factory(element), forKey: element)
        existing?.unmount()
    }

    @JS
    func destruct(element: JSHTMLElement) {
        guard let mounted = elements.removeValue(forKey: element) else { return }
        mounted.unmount()
    }

    @JS
    func setAttribute(element: JSHTMLElement, name: String, value: String?) {
        elements.withValue(forKey: element) { $0.setAttribute(name: name, value: value) }
    }
}

@JSFunction(from: .snippet("/JavaScript/custom-elements.js"))
func defineCustomElement(
    _ name: String,
    _ shadowDOM: String,
    _ observedAttributes: [String],
    _ implementation: CustomElementClass
) throws(JSException)
