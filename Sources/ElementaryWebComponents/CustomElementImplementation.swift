import ElementaryUI
import JavaScriptKit

/// One host element. Attribute values live in ``attributes``; the mount closure captures the
/// view, which already shares those slots.
private final class MountedCustomElement {
    private let mountTarget: JSObject
    private var application: MountedApplication?
    private let attributes: _CustomElementAttributeStorage
    private let mountView: () -> MountedApplication

    init(
        mountTarget: JSObject,
        attributes: _CustomElementAttributeStorage,
        mountView: @escaping () -> MountedApplication
    ) {
        self.mountTarget = mountTarget
        self.attributes = attributes
        self.mountView = mountView
    }

    // Generic initializers must be convenience on final classes for embedded Swift.
    convenience init<Element: CustomElement>(
        name: String,
        host: JSHTMLElement,
        shadow: CustomElements.ShadowRootOptions?,
        factory: () -> Element
    ) throws(JSException) {
        let mountTarget = try Self.resolveMountTarget(host: host, shadow: shadow)
        let view = factory()
        let attributes = Element.__attributes(from: view)
        for attributeName in Element.observedAttributes {
            guard let value = try host.getAttribute(attributeName) else { continue }
            guard attributes.apply(name: attributeName, value: value) else {
                print(
                    "ELEMENTARY WARNING: invalid value for attribute '\(attributeName)' on <\(name)>"
                )
                continue
            }
        }
        self.init(
            mountTarget: mountTarget,
            attributes: attributes,
            mountView: {
                Application(view)._mount(in: mountTarget)
            }
        )
    }

    func mount() {
        guard application == nil else { return }
        application = mountView()
    }

    func unmount() {
        guard let application = application.take() else { return }
        application.unmount()
    }

    func setAttribute(name: String, value: String?) -> Bool {
        attributes.apply(name: name, value: value)
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
final class CustomElementImplementation {
    private let name: String
    private let factory: (JSHTMLElement) throws(JSException) -> MountedCustomElement
    private var elements: [JSHTMLElement: MountedCustomElement] = [:]

    private init(
        name: String,
        factory: @escaping (JSHTMLElement) throws(JSException) -> MountedCustomElement
    ) {
        self.name = name
        self.factory = factory
    }

    convenience init<Element: CustomElement>(
        name: String,
        shadow: CustomElements.ShadowRootOptions?,
        factory: @escaping () -> Element
    ) {
        self.init(name: name) { (host: JSHTMLElement) throws(JSException) -> MountedCustomElement in
            try MountedCustomElement(
                name: name,
                host: host,
                shadow: shadow,
                factory: factory
            )
        }
    }

    @JS
    func connect(element: JSHTMLElement) throws(JSException) {
        if elements[element] == nil {
            elements[element] = try factory(element)
        }
        elements[element]!.mount()
    }

    @JS
    func destruct(element: JSHTMLElement) {
        guard let mounted = elements.removeValue(forKey: element) else { return }
        mounted.unmount()
    }

    @JS
    func setAttribute(element: JSHTMLElement, name: String, value: String?) {
        guard let mounted = elements[element] else { return }
        guard mounted.setAttribute(name: name, value: value) else {
            print("ELEMENTARY WARNING: invalid value for attribute '\(name)' on <\(self.name)>")
            return
        }
    }
}

@JSFunction(from: .snippet("/JavaScript/custom-elements.js"))
func defineCustomElement(
    _ name: String,
    _ shadowDOM: String,
    _ observedAttributes: [String],
    _ implementation: CustomElementImplementation
) throws(JSException)
