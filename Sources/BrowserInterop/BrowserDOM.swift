import JavaScriptKit

@JSClass(jsName: "Document")
public struct JSDocument {
    @JSGetter public var body: JSElement
    @JSFunction public func createElement(_ tagName: String) throws(JSException) -> JSElement
    @JSFunction public func createTextNode(_ text: String) throws(JSException) -> JSNode
    @JSFunction public func querySelector(_ selector: String) throws(JSException) -> JSElement
    @JSFunction public func addEventListener(_ type: String, _ listener: JSObject) throws(JSException)
    @JSFunction public func removeEventListener(_ type: String, _ listener: JSObject) throws(JSException)
}

@JSClass(jsName: "Window")
public struct JSWindow {
    @JSGetter public var scrollX: Double
    @JSGetter public var scrollY: Double
    @JSFunction public func getComputedStyle(_ element: JSElement) throws(JSException) -> JSCSSStyleDeclaration
}

@JSClass(jsName: "Performance")
public struct JSPerformance {
    @JSFunction public func now() throws(JSException) -> Double
}

@JSClass(jsName: "Node")
public struct JSNode {
    @JSGetter public var textContent: String?
    @JSSetter public func setTextContent(_ value: String?) throws(JSException)
}

@JSClass(jsName: "Element")
public struct JSElement {
    @JSGetter public var style: JSCSSStyleDeclaration
    @JSGetter public var textContent: String?
    @JSSetter public func setTextContent(_ value: String?) throws(JSException)
    @JSGetter public var offsetParent: JSElement
    @JSFunction public func setAttribute(_ name: String, _ value: String) throws(JSException)
    @JSFunction public func removeAttribute(_ name: String) throws(JSException)
    @JSFunction public func appendChild(_ child: JSNode) throws(JSException)
    @JSFunction public func removeChild(_ child: JSNode) throws(JSException)
    @JSFunction public func getBoundingClientRect() throws(JSException) -> JSDOMRect
    @JSFunction public func addEventListener(_ type: String, _ listener: JSObject) throws(JSException)
    @JSFunction public func removeEventListener(_ type: String, _ listener: JSObject) throws(JSException)
    @JSFunction public func focus() throws(JSException)
    @JSFunction public func blur() throws(JSException)
    @JSFunction public func animate(_ keyframes: JSObject, _ options: JSObject) throws(JSException) -> JSAnimation
}

@JSClass(jsName: "CSSStyleDeclaration")
public struct JSCSSStyleDeclaration {
    @JSFunction public func getPropertyValue(_ name: String) throws(JSException) -> String
    @JSFunction public func setProperty(_ name: String, _ value: String) throws(JSException)
    @JSFunction public func removeProperty(_ name: String) throws(JSException)
}

@JSClass(jsName: "DOMRect")
public struct JSDOMRect {
    @JSGetter public var x: Double
    @JSGetter public var y: Double
    @JSGetter public var width: Double
    @JSGetter public var height: Double
}

@JSClass(jsName: "Animation")
public struct JSAnimation {
    @JSGetter public var effect: JSAnimationEffect
    @JSSetter public func setCurrentTime(_ value: Double) throws(JSException)
    @JSFunction public func persist() throws(JSException)
    @JSFunction public func pause() throws(JSException)
    @JSFunction public func play() throws(JSException)
    @JSFunction public func cancel() throws(JSException)
    @JSSetter public func setOnfinish(_ callback: JSObject?) throws(JSException)
}

@JSClass(jsName: "AnimationEffect")
public struct JSAnimationEffect {
    @JSFunction public func setKeyframes(_ keyframes: JSObject) throws(JSException)
    @JSFunction public func updateTiming(_ timing: JSObject) throws(JSException)
}

public extension JSNode {
    init(_ element: JSElement) {
        self.init(unsafelyWrapping: element.jsObject)
    }
}

public extension JSElement {
    init(_ node: JSNode) {
        self.init(unsafelyWrapping: node.jsObject)
    }
}

public func jsInsertChild(_ child: JSElement, before sibling: JSElement?, in parent: JSElement) {
    if let sibling {
        _ = parent.jsObject.insertBefore?(child.jsObject.jsValue, sibling.jsObject.jsValue)
    } else {
        _ = parent.jsObject.appendChild?(child.jsObject.jsValue)
    }
}

public func jsReplaceChildren(in parent: JSElement, with children: [JSElement]) {
    parent.jsObject.replaceChildren.function?.callAsFunction(
        this: parent.jsObject,
        arguments: children.map { $0.jsObject.jsValue }
    )
}
