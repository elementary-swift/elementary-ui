@_spi(Benchmarking) import ElementaryUI

private final class RefBox {}
private final class NoOpNodeRef { var text = "" }
private final class NoOpToken {}

final class NoOpInteractor: DOM.Interactor {
    var microtasks: [() -> Void] = []
    var timeouts: [() -> Void] = []
    var rafs: [(Double) -> Void] = []
    var time: Double = 0
    let rootNode = DOM.Node(ref: RefBox())

    func drain() {
        var passes = 0
        while !microtasks.isEmpty || !timeouts.isEmpty || !rafs.isEmpty {
            passes += 1
            precondition(passes < 10_000)

            if !microtasks.isEmpty {
                let tasks = microtasks
                microtasks = []
                for task in tasks { task() }
            }

            if !timeouts.isEmpty {
                let tasks = timeouts
                timeouts = []
                for task in tasks { task() }
            }

            if !rafs.isEmpty {
                let callbacks = rafs
                rafs = []
                time += 1.0 / 60.0
                for callback in callbacks { callback(time * 1000) }
            }
        }
    }

    func makeEventSink(_ handler: @escaping (String, DOM.Event) -> Void) -> DOM.EventSink {
        let _ = handler
        return .init(ref: NoOpToken())
    }

    func makePropertyAccessor(_ node: DOM.Node, name: String) -> DOM.PropertyAccessor {
        let _ = node
        let _ = name
        var value: DOM.PropertyValue = .undefined
        return .init(get: { value }, set: { value = $0 })
    }

    func makeStyleAccessor(_ node: DOM.Node, cssName: String) -> DOM.StyleAccessor {
        let _ = node
        let _ = cssName
        var value = ""
        return .init(get: { value }, set: { value = $0 })
    }

    func makeComputedStyleAccessor(_ node: DOM.Node) -> DOM.ComputedStyleAccessor {
        let _ = node
        return .init(get: { _ in "" })
    }

    func makeFocusAccessor(_ node: DOM.Node, onEvent: @escaping (DOM.FocusEvent) -> Void) -> DOM.FocusAccessor {
        let _ = node
        let _ = onEvent
        return .init(focus: {}, blur: {}, unmount: {})
    }

    func setStyleProperty(_ node: DOM.Node, name: String, value: String) {}
    func removeStyleProperty(_ node: DOM.Node, name: String) {}

    func createText(_ text: String) -> DOM.Node {
        let ref = NoOpNodeRef()
        ref.text = text
        return .init(ref: ref)
    }

    func createElement(_ element: String) -> DOM.Node {
        let _ = element
        return .init(ref: RefBox())
    }

    func setAttribute(_ node: DOM.Node, name: String, value: String?) {}
    func removeAttribute(_ node: DOM.Node, name: String) {}

    func animateElement(_ element: DOM.Node, _ effect: DOM.Animation.KeyframeEffect, onFinish: @escaping () -> Void) -> DOM.Animation {
        let _ = element
        let _ = effect
        let _ = onFinish
        return .init(_cancel: {}, _update: { _ in })
    }

    func getBoundingClientRect(_ node: DOM.Node) -> DOM.Rect { .init(x: 0, y: 0, width: 0, height: 0) }
    func getOffsetParent(_ node: DOM.Node) -> DOM.Node? { nil }
    func getScrollOffset() -> (x: Double, y: Double) { (0, 0) }

    func addEventListener(_ node: DOM.Node, event: String, sink: DOM.EventSink) {}
    func removeEventListener(_ node: DOM.Node, event: String, sink: DOM.EventSink) {}

    func patchText(_ node: DOM.Node, with text: String) {
        (node.ref as? NoOpNodeRef)?.text = text
    }

    func insertChild(_ child: DOM.Node, before sibling: DOM.Node?, in parent: DOM.Node) {}
    func appendChild(_ child: DOM.Node, to parent: DOM.Node) {}
    func removeChild(_ child: DOM.Node, from parent: DOM.Node) {}
    func clearChildren(in parent: DOM.Node) {}

    func querySelector(_ selector: String) -> DOM.Node? { nil }

    func requestAnimationFrame(_ callback: @escaping (Double) -> Void) { rafs.append(callback) }
    func queueMicrotask(_ callback: @escaping () -> Void) { microtasks.append(callback) }
    func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double) { timeouts.append(callback) }
    func getCurrentTime() -> Double { time }
}
