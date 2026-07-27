import Reactivity

// Type-erased node reference
@_spi(Benchmarking)
public enum DOM {
    // TODO: remove anyobject and make reconcier runs generic over this
    @_spi(Benchmarking)
    public protocol Interactor: AnyObject {

        func makeEventSink(_ handler: @escaping (String, Event) -> Void) -> EventSink

        func makePropertyAccessor(_ node: Node, name: String) -> PropertyAccessor
        func makeStyleAccessor(_ node: Node, cssName: String) -> StyleAccessor
        func makeComputedStyleAccessor(_ node: Node) -> ComputedStyleAccessor
        func makeFocusAccessor(_ node: Node, onEvent: @escaping (FocusEvent) -> Void) -> FocusAccessor

        // Fine-grained style property operations
        func setStyleProperty(_ node: Node, name: String, value: String)
        func removeStyleProperty(_ node: Node, name: String)

        func createText(_ text: String) -> Node
        func createElement(_ element: String) -> Node
        func createElementNS(namespaceURI: String, element: String) -> Node

        // Low-level DOM-like attribute APIs
        func setAttribute(_ node: Node, name: String, value: String?)
        func removeAttribute(_ node: Node, name: String)

        // Low-level DOM-like event listener APIs
        func addEventListener(_ node: Node, event: String, sink: borrowing EventSink)
        func removeEventListener(_ node: Node, event: String, sink: borrowing EventSink)
        func patchText(_ node: Node, with text: String)
        // New explicit child list operations
        func insertChild(_ child: Node, before sibling: Node?, in parent: Node)
        func appendChild(_ child: Node, to parent: Node)
        func removeChild(_ child: Node, from parent: Node)
        func clearChildren(in parent: Node)

        // Document query APIs
        func querySelector(_ selector: String) -> Node?

        // TODO: these are more scheduling APIs, but they kind of fit here...
        func queueMicrotask(_ callback: @escaping () -> Void)
        func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double)
        func getCurrentTime() -> Double
    }

    protocol AnimationInteractor: Interactor {
        func animateElement(
            _ element: Node,
            _ effect: Animation.KeyframeEffect,
            onFinish: @escaping () -> Void
        ) -> Animation
    }

    protocol AnimationFrameInteractor: Interactor {
        func requestAnimationFrame(_ callback: @escaping (Double) -> Void)
    }

    protocol LayoutAnimationInteractor:
        AnimationInteractor,
        AnimationFrameInteractor
    {
        func getBoundingClientRect(_ node: Node) -> Rect
        func getOffsetParent(_ node: Node) -> Node?
        func getScrollOffset() -> (x: Double, y: Double)
    }
}

extension DOM.Interactor {
    func runNext(_ callback: @escaping () -> Void) {
        setTimeout(callback, 0)
    }
}

// TODO: fix this with typealias refactoring
#if os(WASI)
extension DOM.Interactor {
    var animationInteractor: BridgeJSDOMInteractor {
        BridgeJSDOMInteractor.shared
    }

    var layoutAnimationInteractor: BridgeJSDOMInteractor {
        BridgeJSDOMInteractor.shared
    }

    var animationFrameInteractor: BridgeJSDOMInteractor {
        BridgeJSDOMInteractor.shared
    }
}
#else
extension DOM.Interactor {
    var animationInteractor: any DOM.AnimationInteractor {
        self as! any DOM.AnimationInteractor
    }

    var layoutAnimationInteractor: any DOM.LayoutAnimationInteractor {
        self as! any DOM.LayoutAnimationInteractor
    }

    var animationFrameInteractor: any DOM.AnimationFrameInteractor {
        self as! any DOM.AnimationFrameInteractor
    }
}
#endif
