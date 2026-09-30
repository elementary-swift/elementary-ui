import JavaScriptKit

extension Application {
    public func _mount(in element: JSObject) -> MountedApplication {
        let runtime = ApplicationRuntime(dom: defaultDOMInteractor, domRoot: DOM.Node(ref: element), appView: self.contentView)
        return MountedApplication(unmount: runtime.unmount)
    }
}
