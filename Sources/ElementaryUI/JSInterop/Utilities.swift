import JavaScriptKit

extension BridgeJSDOMInteractor {
    static var shared = BridgeJSDOMInteractor()
}

extension Application {
    public func _mount(in element: JSObject) -> MountedApplication {
        let runtime = ApplicationRuntime(dom: BridgeJSDOMInteractor.shared, domRoot: DOM.Node(element), appView: self.contentView)
        return MountedApplication(unmount: runtime.unmount)
    }
}
