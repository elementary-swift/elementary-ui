import JavaScriptKit

extension BridgeJSDOMInteractor {
    static var shared = BridgeJSDOMInteractor()
}

let defaultDOMInteractor: DOMInteractor = BridgeJSDOMInteractor.shared

extension Application {
    public func _mount(in element: JSObject) -> MountedApplication {
        let runtime = ApplicationRuntime(dom: defaultDOMInteractor, domRoot: DOM.Node(element), appView: self.contentView)
        return MountedApplication(unmount: runtime.unmount)
    }
}
