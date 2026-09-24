import ElementaryUI
import JavaScriptKit

/// One host element. Attribute values live in ``attributes``; the mount closure captures the
/// view, which already shares those slots.
struct MountedCustomElement: ~Copyable {
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

        for attributeName in Element.__observedAttributes {
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

extension _CustomElementHostContext {
    func setAttribute(_ name: String, value: String?, onElement elementName: String) {
        guard self.trySetAttribute(name, value: value) else {
            print("ELEMENTARY WARNING: invalid value for attribute '\(name)' on <\(elementName)>")
            return
        }
    }
}

extension CustomElementBridge {
    convenience init<Element: CustomElement>(
        name: String,
        shadow: CustomElements.ShadowRootOptions?,
        factory: @escaping () -> Element
    ) {
        self.init(observedAttributes: Element.__observedAttributes) {
            (host: JSHTMLElement) throws(JSException) -> MountedCustomElement in
            try MountedCustomElement(
                elementName: name,
                host: host,
                shadow: shadow,
                factory: factory
            )
        }
    }
}
