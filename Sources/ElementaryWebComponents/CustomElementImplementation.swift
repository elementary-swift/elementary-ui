import ElementaryUI
import JavaScriptKit

private final class MountedCustomElement<Element: CustomElement> {
    var view: Element
    private let mountTarget: MountTarget
    private var application: MountedApplication?

    init(
        view: Element,
        host: JSHTMLElement,
        shadowDOM: CustomElementShadowDOM
    ) throws(JSException) {
        self.view = view

        switch shadowDOM.mode {
        case .open:
            let shadowRoot: JSShadowRoot
            if let existingShadowRoot = try host.shadowRoot {
                shadowRoot = existingShadowRoot
            } else {
                shadowRoot = try host.attachShadow(JSShadowRootInit(mode: "open"))
            }
            try shadowRoot.setAdoptedStyleSheets(
                shadowDOM.styleSheets.map { $0.jsStyleSheet }
            )
            mountTarget = .shadowRoot(shadowRoot)
        case .none:
            mountTarget = .host(host)
        }
    }

    func mount() {
        guard application == nil else { return }
        application = Application(view)._mount(in: mountTarget.jsObject)
    }

    func unmount() {
        guard let application = application.take() else { return }
        application.unmount()
    }

    private enum MountTarget {
        case host(JSHTMLElement)
        case shadowRoot(JSShadowRoot)

        var jsObject: JSObject {
            switch self {
            case .host(let host): host.jsObject
            case .shadowRoot(let shadowRoot): shadowRoot.jsObject
            }
        }
    }
}

private final class CustomElementManager<Element: CustomElement> {
    private let name: String
    private let shadowDOM: CustomElementShadowDOM
    private let factory: () -> Element
    private var elements: [JSHTMLElement: MountedCustomElement<Element>] = [:]

    init(
        name: String,
        shadowDOM: CustomElementShadowDOM,
        factory: @escaping () -> Element
    ) {
        self.name = name
        self.shadowDOM = shadowDOM
        self.factory = factory
    }

    func construct(_ element: JSHTMLElement) throws(JSException) {
        guard elements[element] == nil else { return }
        elements[element] = try MountedCustomElement(
            view: factory(),
            host: element,
            shadowDOM: shadowDOM
        )
    }

    func connect(_ element: JSHTMLElement) throws(JSException) {
        try construct(element)
        mountedElement(for: element).mount()
    }

    func destruct(_ element: JSHTMLElement) {
        guard let mounted = elements.removeValue(forKey: element) else { return }
        mounted.unmount()
    }

    func setAttribute(_ element: JSHTMLElement, name attributeName: String, value: String?) {
        guard let mounted = elements[element] else { return }
        guard mounted.view.setAttribute(name: attributeName, value: value) else {
            print("ELEMENTARY WARNING: invalid value for attribute '\(attributeName)' on <\(name)>")
            return
        }
    }

    private func mountedElement(for element: JSHTMLElement) -> MountedCustomElement<Element> {
        guard let mounted = elements[element] else {
            fatalError("Custom element <\(name)> has not been constructed")
        }
        return mounted
    }
}

@JS
final class CustomElementImplementation {
    private let _construct: (JSHTMLElement) throws(JSException) -> Void
    private let _connect: (JSHTMLElement) throws(JSException) -> Void
    private let _destruct: (JSHTMLElement) -> Void
    private let _setAttribute: (JSHTMLElement, String, String?) -> Void

    private init(
        construct: @escaping (JSHTMLElement) throws(JSException) -> Void,
        connect: @escaping (JSHTMLElement) throws(JSException) -> Void,
        destruct: @escaping (JSHTMLElement) -> Void,
        setAttribute: @escaping (JSHTMLElement, String, String?) -> Void
    ) {
        _construct = construct
        _connect = connect
        _destruct = destruct
        _setAttribute = setAttribute
    }

    convenience init<Element: CustomElement>(
        name: String,
        shadowDOM: CustomElementShadowDOM,
        factory: @escaping () -> Element
    ) {
        let manager = CustomElementManager(
            name: name,
            shadowDOM: shadowDOM,
            factory: factory
        )
        self.init(
            construct: manager.construct,
            connect: manager.connect,
            destruct: manager.destruct,
            setAttribute: manager.setAttribute
        )
    }

    @JS
    func construct(element: JSHTMLElement) throws(JSException) {
        try _construct(element)
    }

    @JS
    func connect(element: JSHTMLElement) throws(JSException) {
        try _connect(element)
    }

    @JS
    func destruct(element: JSHTMLElement) {
        _destruct(element)
    }

    @JS
    func setAttribute(element: JSHTMLElement, name: String, value: String?) {
        _setAttribute(element, name, value)
    }
}

@JSFunction(from: .snippet("/JavaScript/custom-elements.js"))
func defineCustomElement(
    _ name: String,
    _ shadowDOM: String,
    _ observedAttributes: [String],
    _ implementation: CustomElementImplementation
) throws(JSException)
