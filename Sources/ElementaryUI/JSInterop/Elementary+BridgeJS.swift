import BrowserInterop
@_spi(BridgeJS) import JavaScriptKit

extension DOM.Node {
    init(_ node: JSObject) { self.init(ref: node) }
    //var jsObject: JSObject { ref as! JSObject }
    var jsNode: JSNode { JSNode(unsafelyWrapping: ref as! JSObject) }
    var jsElement: JSElement { JSElement(unsafelyWrapping: ref as! JSObject) }
}

extension DOM.EventSink {
    var jsClosure: JSEventCallback {
        switch self.storage {
        case let .js(closure):
            return closure
        case .ref:
            fatalError("ref is not a JSEventCallback")
        }
    }
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
        let closure = JSEventCallback.make { e in
            handler(try! e.type, DOM.Event(e.jsObject))
        }

        return .init(js: closure)
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
            js:
                JSEventCallback.make { _ in
                    onEvent(.focus)
                }
        )

        let blurSink = DOM.EventSink(
            js: JSEventCallback.make { _ in
                onEvent(.blur)
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
            focusSink: focusSink,
            blurSink: blurSink,
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
        let node = try! _document.createTextNode(text)
        return .init(ref: node.jsObject)
    }

    func createElement(_ element: String) -> DOM.Node {
        let node = try! _document.createElement(element)
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
        guard let animation = try? element.jsElement.animate(effect.jsKeyframes, effect.jsEffectOptions) else {
            return .init(_cancel: {}, _update: { _ in })
        }

        _ = try? animation.persist()

        if effect.duration == 0 {
            _ = try? animation.pause()
        }

        _ = try? animation.setOnfinish(onFinish)

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

    func addEventListener(_ node: DOM.Node, event: String, sink: borrowing DOM.EventSink) {
        _ = try? node.jsElement.addEventListener(event, sink.jsClosure)
    }

    func removeEventListener(_ node: DOM.Node, event: String, sink: borrowing DOM.EventSink) {
        _ = try? node.jsElement.removeEventListener(event, sink.jsClosure)
    }

    func patchText(_ node: DOM.Node, with text: String) {
        _ = try? node.jsNode.setTextContent(text)
    }

    func insertChild(_ child: DOM.Node, before sibling: DOM.Node?, in parent: DOM.Node) {
        if let sibling {
            _ = try? parent.jsElement.insertBefore(
                child.jsNode,
                sibling.jsNode
            )
        } else {
            _ = try? parent.jsElement.appendChild(child.jsNode)
        }
    }

    func appendChild(_ child: DOM.Node, to parent: DOM.Node) {
        _ = try? parent.jsElement.appendChild(child.jsNode)
    }

    func removeChild(_ child: DOM.Node, from parent: DOM.Node) {
        _ = try? parent.jsElement.removeChild(child.jsNode)
    }

    func clearChildren(in parent: DOM.Node) {
        _ = try? parent.jsElement.replaceChildren()
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

extension DOM.Animation.KeyframeEffect {
    var jsEffectOptions: JSKeyframeEffectOptions {
        .init(duration: duration, fill: .forwards, composite: self.composite.jsValue)
    }

    var jsTiming: JSAnimationTiming {
        .init(duration: duration)
    }

    var jsKeyframes: JSObject {
        // NOTE: this could be a [String: [String]] but that doesn't work well for embedded because it requires unicode tables
        // caching the property name would be nice....
        [
            property: values.jsValue
        ]
    }
}

extension DOM.Animation.CompositeOperation {
    var jsValue: JSCompositeOperation {
        switch self {
        case .replace:
            return .replace
        case .add:
            return .add
        case .accumulate:
            return .accumulate
        }
    }
}

extension DOM.Event {
    init(_ event: JSObject) { self.init(ref: event) }
    var jsObject: JSObject { ref as! JSObject }
}

extension DOM.PropertyValue {
    var jsValue: JSValue {
        switch self {
        case let .string(value):
            return value.jsValue
        case let .number(value):
            return value.jsValue
        case let .boolean(value):
            return value.jsValue
        case let .stringArray(value):
            return value.jsValue
        case .null:
            return .null
        case .undefined:
            return .undefined
        }
    }

    init?(_ jsValue: JSValue) {
        if let value = jsValue.string {
            self = .string(value)
        } else if let value = jsValue.number {
            self = .number(value)
        } else if let value = jsValue.boolean {
            self = .boolean(value)
        } else if let object = jsValue.object {
            guard let array = JSArray(object) else { return nil }
            self = .stringArray(array.compactMap { $0.string })
        } else if jsValue.isNull {
            self = .null
        } else if jsValue.isUndefined {
            self = .undefined
        } else {
            return nil
        }
    }
}
