@_spi(BridgeJS) import JavaScriptKit

@JSClass(jsName: "Document")
public struct JSDocument {
    @JSGetter public var body: JSElement
    @JSFunction public func createElement(_ tagName: String) throws(JSException) -> JSElement
    @JSFunction public func createTextNode(_ text: String) throws(JSException) -> JSNode
    @JSFunction public func querySelector(_ selector: String) throws(JSException) -> JSElement
    @JSFunction public func addEventListener(_ type: String, _ listener: JSTypedClosure<(JSEvent) -> Void>) throws(JSException)
    @JSFunction public func removeEventListener(_ type: String, _ listener: JSTypedClosure<(JSEvent) -> Void>) throws(JSException)
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
    @JSSetter public func setTextContent(_ value: String) throws(JSException)
}

@JSClass(jsName: "Element")
public struct JSElement {
    @JSGetter public var style: JSCSSStyleDeclaration
    @JSGetter public var offsetParent: JSElement
    @JSFunction public func setAttribute(_ name: String, _ value: String) throws(JSException)
    @JSFunction public func removeAttribute(_ name: String) throws(JSException)
    @JSFunction public func appendChild(_ child: JSNode) throws(JSException)
    @JSFunction public func removeChild(_ child: JSNode) throws(JSException)
    @JSFunction public func insertBefore(_ newChild: JSNode, _ refChild: JSNode) throws(JSException)
    @JSFunction public func replaceChildren() throws(JSException)
    @JSFunction public func getBoundingClientRect() throws(JSException) -> JSDOMRect
    @JSFunction public func addEventListener(_ type: String, _ listener: JSEventCallback) throws(JSException)
    @JSFunction public func removeEventListener(_ type: String, _ listener: JSEventCallback) throws(JSException)
    @JSFunction public func focus() throws(JSException)
    @JSFunction public func blur() throws(JSException)
    @JSFunction public func animate(
        _ keyframes: JSAnimationKeyframes,
        _ options: JSKeyframeEffectOptions
    ) throws(JSException) -> JSAnimation
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
    @JSSetter public func setOnfinish(_ callback: @escaping () -> Void) throws(JSException)
}

@JSClass(jsName: "AnimationEffect")
public struct JSAnimationEffect {
    @JSFunction public func setKeyframes(_ keyframes: JSAnimationKeyframes) throws(JSException)
    @JSFunction public func updateTiming(_ timing: JSAnimationTiming) throws(JSException)
}

// NOTE: this does not work well for embedded because it requires unicode tables
// public typealias JSAnimationKeyframes = [String: [String]]
public typealias JSAnimationKeyframes = JSObject

@JS public enum JSCompositeOperation: String {
    case replace
    case add
    case accumulate
}

@JS public enum JSFillMode: String {
    case none
    case forwards
    case backwards
    case both
    case auto
}

@JS
public struct JSKeyframeEffectOptions {
    public var duration: Int
    public var fill: JSFillMode
    public var composite: JSCompositeOperation

    public init(duration: Int, fill: JSFillMode, composite: JSCompositeOperation) {
        self.duration = duration
        self.fill = fill
        self.composite = composite
    }
}

@JS
public struct JSAnimationTiming {
    public var duration: Int

    public init(duration: Int) {
        self.duration = duration
    }
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

extension JSNode? {
    func bridgeJSLowerParameter() -> (Int32, Int32) {
        if let node = self {
            return (1, node.jsObject.bridgeJSLowerParameter())
        } else {
            return (0, 0)
        }
    }

}
