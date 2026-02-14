import Reactivity

// Type-erased node reference
enum DOM {
    // TODO: remove anyobject and make reconcier runs generic over this
    protocol Interactor: AnyObject {

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

        // Low-level DOM-like attribute APIs
        func setAttribute(_ node: Node, name: String, value: String?)
        func removeAttribute(_ node: Node, name: String)

        func animateElement(_ element: Node, _ effect: Animation.KeyframeEffect, onFinish: @escaping () -> Void) -> Animation

        // Measurement API for FLIP animations
        func getBoundingClientRect(_ node: Node) -> Rect
        func getOffsetParent(_ node: Node) -> Node?

        // Scroll offset API for FLIP animations
        func getScrollOffset() -> (x: Double, y: Double)

        // Low-level DOM-like event listener APIs
        func addEventListener(_ node: Node, event: String, sink: EventSink)
        func removeEventListener(_ node: Node, event: String, sink: EventSink)
        func patchText(_ node: Node, with text: String)
        func replaceChildren(_ children: [Node], in parent: Node)
        // New explicit child list operations
        func insertChild(_ child: Node, before sibling: Node?, in parent: Node)
        func removeChild(_ child: Node, from parent: Node)

        // Document query APIs
        func querySelector(_ selector: String) -> Node?

        // TODO: these are more scheduling APIs, but they kind of fit here...
        func requestAnimationFrame(_ callback: @escaping (Double) -> Void)
        func queueMicrotask(_ callback: @escaping () -> Void)
        func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double)
        func getCurrentTime() -> Double
    }
}

extension DOM.Interactor {
    func runNext(_ callback: @escaping () -> Void) {
        setTimeout(callback, 0)
    }
}
