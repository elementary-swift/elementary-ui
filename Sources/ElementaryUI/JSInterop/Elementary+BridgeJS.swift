import BrowserInterop
import JavaScriptKit

extension DOM.Node {
    init(_ node: JSObject) { self.init(ref: node) }
    //var jsObject: JSObject { ref as! JSObject }
    var jsNode: JSNode { JSNode(unsafelyWrapping: ref as! JSObject) }
    var jsElement: JSElement { JSElement(unsafelyWrapping: ref as! JSObject) }
}

final class BridgeJSDOMInteractor: DOM.Interactor {
    private let _document: JSDocument
    private let _window: JSWindow
    private let _performance: JSPerformance

    init() {
        _document = try! BrowserInterop.document
        _window = try! BrowserInterop.window
        _performance = try! BrowserInterop.performance
    }

    func makeEventSink(_ handler: @escaping (String, DOM.Event) -> Void) -> DOM.EventSink {
        .init(
            JSClosure { arguments in
                guard arguments.count >= 1 else { return .undefined }
                guard let eventObject = arguments[0].object else {
                    return .undefined
                }
                let type = (try? JSEvent(unsafelyWrapping: eventObject).type) ?? ""
                if type.isEmpty {
                    return .undefined
                }

                handler(type, .init(eventObject))
                return .undefined
            }
        )
    }

    func makePropertyAccessor(_ node: DOM.Node, name: String) -> DOM.PropertyAccessor {
        .init(
            get: { .init(node.jsElement.jsObject[name]) },
            set: { node.jsElement.jsObject[name] = $0.jsValue }
        )
    }

    func makeStyleAccessor(_ node: DOM.Node, cssName: String) -> DOM.StyleAccessor {
        .init(
            get: {
                let element = node.jsElement
                return (try? element.style.getPropertyValue(cssName)) ?? ""
            },
            set: {
                let element = node.jsElement
                _ = try? element.style.setProperty(cssName, $0)
            }
        )
    }

    func makeComputedStyleAccessor(_ node: DOM.Node) -> DOM.ComputedStyleAccessor {
        .init(
            get: { cssName in
                let element = node.jsElement
                let style = (try? self._window.getComputedStyle(element)) ?? (try? element.style)
                return (try? style?.getPropertyValue(cssName)) ?? ""
            }
        )
    }

    func makeFocusAccessor(_ node: DOM.Node, onEvent: @escaping (DOM.FocusEvent) -> Void) -> DOM.FocusAccessor {
        let focusSink = DOM.EventSink(
            JSClosure { _ in
                onEvent(.focus)
                return .undefined
            }
        )

        let blurSink = DOM.EventSink(
            JSClosure { _ in
                onEvent(.blur)
                return .undefined
            }
        )

        addEventListener(node, event: "focus", sink: focusSink)
        addEventListener(node, event: "blur", sink: blurSink)

        return .init(
            focus: {
                _ = try? node.jsElement.focus()
            },
            blur: {
                _ = try? node.jsElement.blur()
            },
            unmount: { [self] in
                self.removeEventListener(node, event: "focus", sink: focusSink)
                self.removeEventListener(node, event: "blur", sink: blurSink)
            }
        )
    }

    func setStyleProperty(_ node: DOM.Node, name: String, value: String) {
        let element = node.jsElement
        _ = try? element.style.setProperty(name, value)
    }

    func removeStyleProperty(_ node: DOM.Node, name: String) {
        let element = node.jsElement
        _ = try? element.style.removeProperty(name)
    }

    func createText(_ text: String) -> DOM.Node {
        guard let node = try? _document.createTextNode(text) else {
            return .init(ref: JSObject())
        }
        return .init(ref: node.jsObject)
    }

    func createElement(_ element: String) -> DOM.Node {
        guard let node = try? _document.createElement(element) else {
            return .init(ref: JSObject())
        }
        return .init(ref: node.jsObject)
    }

    func setAttribute(_ node: DOM.Node, name: String, value: String?) {
        let element = node.jsElement
        if let value {
            _ = try? element.setAttribute(name, value)
        } else {
            _ = try? element.removeAttribute(name)
        }
    }

    func removeAttribute(_ node: DOM.Node, name: String) {
        _ = try? node.jsElement.removeAttribute(name)
    }

    func animateElement(_ element: DOM.Node, _ effect: DOM.Animation.KeyframeEffect, onFinish: @escaping () -> Void) -> DOM.Animation {
        guard let animation = try? element.jsElement.animate(effect.jsKeyframes, effect.jsTiming) else {
            return .init(_cancel: {}, _update: { _ in })
        }

        _ = try? animation.persist()

        if effect.duration == 0 {
            _ = try? animation.pause()
        }

        _ = try? animation.setOnfinish(
            JSClosure { _ in
                onFinish()
                return .undefined
            }
        )

        return .init(
            _cancel: {
                _ = try? animation.cancel()
            },
            _update: { effect in
                logTrace("updating animation with effect \(effect)")
                _ = try? animation.effect.setKeyframes(effect.jsKeyframes)
                _ = try? animation.effect.updateTiming(effect.jsTiming)
                _ = try? animation.setCurrentTime(0)
                if effect.duration > 0 {
                    _ = try? animation.play()
                }
            }
        )
    }

    func addEventListener(_ node: DOM.Node, event: String, sink: DOM.EventSink) {
        _ = try? node.jsElement.addEventListener(event, sink.jsClosure)
    }

    func removeEventListener(_ node: DOM.Node, event: String, sink: DOM.EventSink) {
        _ = try? node.jsElement.removeEventListener(event, sink.jsClosure)
    }

    func patchText(_ node: DOM.Node, with text: String) {
        _ = try? node.jsNode.setTextContent(text)
    }

    func replaceChildren(_ children: [DOM.Node], in parent: DOM.Node) {
        // TODO: this is not supported rn - maybe create a hand-made JS tranpoline for this
        // _ = try? parent.jsElement.replaceChildren(children.map { $0.jsNode })

        parent.jsNode.jsObject.replaceChildren.function!.callAsFunction(
            this: parent.jsElement.jsObject,
            arguments: children.map { $0.jsNode.jsObject.jsValue }
        )
    }

    func insertChild(_ child: DOM.Node, before sibling: DOM.Node?, in parent: DOM.Node) {
        _ = try? parent.jsElement.insertBefore(
            child.jsNode,
            sibling.map({ $0.jsNode })
        )
    }

    func removeChild(_ child: DOM.Node, from parent: DOM.Node) {
        _ = try? parent.jsElement.removeChild(child.jsNode)
    }

    func getBoundingClientRect(_ node: DOM.Node) -> DOM.Rect {
        guard let rect = try? node.jsElement.getBoundingClientRect() else {
            return DOM.Rect(x: 0, y: 0, width: 0, height: 0)
        }
        return DOM.Rect(
            x: (try? rect.x) ?? 0,
            y: (try? rect.y) ?? 0,
            width: (try? rect.width) ?? 0,
            height: (try? rect.height) ?? 0
        )
    }

    func getOffsetParent(_ node: DOM.Node) -> DOM.Node? {
        guard let parent = try? node.jsElement.offsetParent else {
            return nil
        }
        if parent.jsObject.jsValue.isNull || parent.jsObject.jsValue.isUndefined {
            return nil
        }
        return DOM.Node(ref: parent.jsObject)
    }

    func requestAnimationFrame(_ callback: @escaping (Double) -> Void) {
        _ = try! BrowserInterop.requestAnimationFrame(callback)
    }

    func queueMicrotask(_ callback: @escaping () -> Void) {
        try! BrowserInterop.queueMicrotask(callback)
    }

    func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double) {
        try! BrowserInterop.setTimeout(callback, timeout)
    }

    func getCurrentTime() -> Double {
        try! _performance.now() / 1000
    }

    func getScrollOffset() -> (x: Double, y: Double) {
        (
            x: (try? _window.scrollX) ?? 0,
            y: (try? _window.scrollY) ?? 0
        )
    }

    func querySelector(_ selector: String) -> DOM.Node? {
        guard let element = try? _document.querySelector(selector) else {
            return nil
        }
        if element.jsObject.jsValue.isNull || element.jsObject.jsValue.isUndefined {
            return nil
        }
        return DOM.Node(ref: element.jsObject)
    }
}

private extension DOM.Animation.KeyframeEffect {
    var jsKeyframes: JSObject {
        let object = JSObject()
        object[property] = values.jsValue
        return object
    }

    var jsTiming: JSObject {
        let object = JSObject()
        object["duration"] = duration.jsValue
        object["fill"] = "forwards".jsValue
        if composite != .replace {
            object["composite"] = composite.jsValue
        }
        return object
    }
}
