import JavaScriptKit

extension JSKitDOMInteractor {
    static var shared = JSKitDOMInteractor()
}

extension Application {
    public func _mount(in element: JSObject) -> MountedApplication {
        let runtime = ApplicationRuntime(dom: JSKitDOMInteractor.shared, domRoot: DOM.Node(element), appView: self.contentView)
        return MountedApplication(unmount: runtime.unmount)
    }

    @_spi(Benchmarking)
    public func _mount<Interactor: DOM.Interactor>(
        dom: Interactor,
        root: DOM.Node
    ) -> MountedApplication {
        let runtime = ApplicationRuntime(dom: dom, domRoot: root, appView: self.contentView)
        return MountedApplication(unmount: runtime.unmount)
    }
}
