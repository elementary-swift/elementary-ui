import JavaScriptKit

extension JSKitDOMInteractor {
    static var shared = JSKitDOMInteractor()
}

extension Application {
    public func _mount(in element: JSObject) -> MountedApplication {
        let runtime = ApplicationRuntime(dom: JSKitDOMInteractor.shared, domRoot: DOM.Node(element), appView: self.contentView)
        return MountedApplication(unmount: runtime.unmount)
    }
}
