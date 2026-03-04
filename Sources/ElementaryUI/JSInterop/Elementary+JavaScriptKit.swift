import JavaScriptKit

extension DOM.Event {
    init(_ event: JSObject) { self.init(ref: event) }
    var jsObject: JSObject { ref as! JSObject }
}

extension DOM.EventSink {
    init(_ sink: JSClosure) { self.init(ref: sink) }
    var jsClosure: JSClosure { ref as! JSClosure }
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

// final class JSKitDOMInteractor: DOM.Interactor {
//     private let jsDocument = JSObject.global.document.object!
//     private let jsSetTimeout = JSObject.global.setTimeout.function!
//     private let jsRequestAnimationFrame = JSObject.global.requestAnimationFrame.function!
//     private let jsQueueMicrotask = JSObject.global.queueMicrotask.function!
//     private let jsPerformance = JSObject.global.performance.object!
//     // Cache frequently used JS function lookups once for hot DOM paths.
//     private let jsCreateTextNode = JSObject.global.document.object!.createTextNode.function!
//     private let jsCreateElement = JSObject.global.document.object!.createElement.function!
//     private let jsQuerySelector = JSObject.global.document.object!.querySelector.function!
//     private let jsPerformanceNow = JSObject.global.performance.object!.now.function!
//     private let jsNodeSetAttribute = JSObject.global.Element.prototype.setAttribute.function!
//     private let jsNodeRemoveAttribute = JSObject.global.Element.prototype.removeAttribute.function!
//     private let jsNodeAddEventListener = JSObject.global.EventTarget.prototype.addEventListener.function!
//     private let jsNodeRemoveEventListener = JSObject.global.EventTarget.prototype.removeEventListener.function!
//     private let jsNodeReplaceChildren = JSObject.global.Element.prototype.replaceChildren.function!
//     private let jsNodeInsertBefore = JSObject.global.Node.prototype.insertBefore.function!
//     private let jsNodeAppendChild = JSObject.global.Node.prototype.appendChild.function!
//     private let jsNodeRemoveChild = JSObject.global.Node.prototype.removeChild.function!
//     private let jsNodeGetBoundingClientRect = JSObject.global.Element.prototype.getBoundingClientRect.function!

//     private let staticStrings = StaticJSStringCache()

//     init() {}

//     func makeEventSink(_ handler: @escaping (String, DOM.Event) -> Void) -> DOM.EventSink {
//         .init(
//             JSClosure { arguments in
//                 guard arguments.count >= 1 else { return .undefined }

//                 guard let event = arguments[0].object, let type = event.type.string else {
//                     return .undefined
//                 }

//                 handler(type, .init(event))
//                 return .undefined
//             }
//         )
//     }

//     func makePropertyAccessor(_ node: DOM.Node, name: String) -> DOM.PropertyAccessor {
//         let propertyName = JSString(name)
//         let object = node.jsObject
//         return .init(
//             get: { .init(getJSValue(this: object, name: propertyName)) },
//             set: { setJSValue(this: object, name: propertyName, value: $0.jsValue) }
//         )
//     }

//     func makeStyleAccessor(_ node: DOM.Node, cssName: String) -> DOM.StyleAccessor {
//         let propertyName = JSString(cssName)
//         let style = node.jsObject.style

//         return .init(
//             get: { style.getPropertyValue(propertyName.jsValue).string ?? "" },
//             set: { _ = style.setProperty(propertyName.jsValue, $0.jsValue) }
//         )
//     }

//     func makeComputedStyleAccessor(_ node: DOM.Node) -> DOM.ComputedStyleAccessor {
//         let jsWindow = JSObject.global.window.object!
//         let computedStyle = jsWindow.getComputedStyle!(node.jsObject.jsValue).object!

//         return .init(
//             get: { cssName in
//                 let propertyName = JSString(cssName)
//                 return computedStyle.getPropertyValue!(propertyName.jsValue).string ?? ""
//             }
//         )
//     }

//     func makeFocusAccessor(_ node: DOM.Node, onEvent: @escaping (DOM.FocusEvent) -> Void) -> DOM.FocusAccessor {
//         let focusSink = DOM.EventSink(
//             JSClosure { _ in
//                 onEvent(.focus)
//                 return .undefined
//             }
//         )

//         let blurSink = DOM.EventSink(
//             JSClosure { _ in
//                 onEvent(.blur)
//                 return .undefined
//             }
//         )

//         addEventListener(node, event: "focus", sink: focusSink)
//         addEventListener(node, event: "blur", sink: blurSink)

//         return .init(
//             focus: {
//                 _ = node.jsObject.focus!()
//             },
//             blur: {
//                 _ = node.jsObject.blur!()
//             },
//             unmount: { [self] in
//                 self.removeEventListener(node, event: "focus", sink: focusSink)
//                 self.removeEventListener(node, event: "blur", sink: blurSink)
//             }
//         )
//     }

//     func setStyleProperty(_ node: DOM.Node, name: String, value: String) {
//         let style = node.jsObject.style
//         _ = style.setProperty(JSString(name).jsValue, JSString(value).jsValue)
//     }

//     func removeStyleProperty(_ node: DOM.Node, name: String) {
//         let style = node.jsObject.style
//         _ = style.removeProperty(JSString(name).jsValue)
//     }

// func createText(_ text: String) -> DOM.Node {
//     .init(jsCreateTextNode.callAsFunction(this: jsDocument, arguments: [text.jsValue]).object!)
// }

// func createElement(_ element: String) -> DOM.Node {
//     DOM.Node(
//         jsCreateElement.callAsFunction(
//             this: jsDocument,
//             arguments: [
//                 staticStrings.getOrAddStaticString(element).jsValue
//             ]
//         ).object!
//     )
// }

// // Low-level DOM-like operations used by protocol extensions
// func setAttribute(_ node: DOM.Node, name: String, value: String?) {
//     _ = jsNodeSetAttribute.callAsFunction(
//         this: node.jsObject,
//         arguments: [
//             staticStrings.getOrAddStaticString(name).jsValue,
//             value.jsValue,
//         ]
//     )
// }

// func removeAttribute(_ node: DOM.Node, name: String) {

//     _ = jsNodeRemoveAttribute.callAsFunction(
//         this: node.jsObject,
//         arguments: [
//             staticStrings.getOrAddStaticString(name).jsValue
//         ]
//     )
// }

//     func animateElement(_ element: DOM.Node, _ effect: DOM.Animation.KeyframeEffect, onFinish: @escaping () -> Void) -> DOM.Animation {
//         let animation = element.jsObject.animate!(
//             effect.jsKeyframes,
//             effect.jsTiming
//         )

//         _ = animation.persist()

//         if effect.duration == 0 {
//             _ = animation.pause()
//         }

//         animation.onfinish =
//             JSClosure { _ in
//                 onFinish()
//                 return .undefined
//             }.jsValue

//         return .init(
//             _cancel: {
//                 _ = animation.cancel()
//             },
//             _update: { effect in
//                 logTrace("updating animation with effect \(effect)")
//                 _ = animation.effect.setKeyframes(effect.jsKeyframes)
//                 _ = animation.effect.updateTiming(effect.jsTiming)
//                 // Reset to start of new keyframes - required for retargeting mid-animation
//                 // New keyframes always start from current presentation value
//                 animation.currentTime = 0.jsValue
//                 if effect.duration > 0 {
//                     _ = animation.play()
//                 }
//             }
//         )
//     }

// func addEventListener(_ node: DOM.Node, event: String, sink: DOM.EventSink) {
//     _ = jsNodeAddEventListener.callAsFunction(
//         this: node.jsObject,
//         arguments: [
//             staticStrings.getOrAddStaticString(event).jsValue,
//             sink.jsClosure.jsValue,
//         ]
//     )
// }

// func removeEventListener(_ node: DOM.Node, event: String, sink: DOM.EventSink) {
//     _ = jsNodeRemoveEventListener.callAsFunction(
//         this: node.jsObject,
//         arguments: [
//             staticStrings.getOrAddStaticString(event).jsValue,
//             sink.jsClosure.jsValue,
//         ]
//     )
// }

//     func patchText(_ node: DOM.Node, with text: String) {
//         node.jsObject.textContent = text.jsValue
//     }

// func replaceChildren(_ children: [DOM.Node], in parent: DOM.Node) {
//     logTrace("setting \(children.count) children in \(parent)")
//     jsNodeReplaceChildren.callAsFunction(
//         this: parent.jsObject,
//         arguments: children.map { $0.jsObject.jsValue }
//     )
// }

// func insertChild(_ child: DOM.Node, before sibling: DOM.Node?, in parent: DOM.Node) {
//     if let s = sibling {
//         _ = jsNodeInsertBefore.callAsFunction(this: parent.jsObject, arguments: [child.jsObject.jsValue, s.jsObject.jsValue])
//     } else {
//         _ = jsNodeAppendChild.callAsFunction(this: parent.jsObject, arguments: [child.jsObject.jsValue])
//     }
// }

// func removeChild(_ child: DOM.Node, from parent: DOM.Node) {
//     _ = jsNodeRemoveChild.callAsFunction(this: parent.jsObject, arguments: [child.jsObject.jsValue])
// }

// func getBoundingClientRect(_ node: DOM.Node) -> DOM.Rect {
//     let rect = jsNodeGetBoundingClientRect.callAsFunction(this: node.jsObject)
//     return DOM.Rect(
//         x: rect.x.number ?? 0,
//         y: rect.y.number ?? 0,
//         width: rect.width.number ?? 0,
//         height: rect.height.number ?? 0
//     )
// }

//     func getOffsetParent(_ node: DOM.Node) -> DOM.Node? {
//         if let offsetParent = node.jsObject.offsetParent.object {
//             return DOM.Node(offsetParent)
//         }
//         return nil
//     }

//     func requestAnimationFrame(_ callback: @escaping (Double) -> Void) {
//         // TODO: optimize this
//         jsRequestAnimationFrame(
//             JSOneshotClosure { args in
//                 callback(args[0].number!)
//                 return .undefined
//             }.jsValue
//         )
//     }

//     func queueMicrotask(_ callback: @escaping () -> Void) {
//         jsQueueMicrotask(
//             JSOneshotClosure { args in
//                 callback()
//                 return .undefined
//             }.jsValue
//         )
//     }

//     func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double) {
//         jsSetTimeout(
//             JSOneshotClosure { args in
//                 callback()
//                 return .undefined
//             }.jsValue,
//             timeout
//         )
//     }

//     func getCurrentTime() -> Double {
//         jsPerformanceNow.callAsFunction(this: jsPerformance).number! / 1000
//     }

//     func getScrollOffset() -> (x: Double, y: Double) {
//         let window = JSObject.global.window.object!
//         return (
//             x: window.scrollX.number ?? 0,
//             y: window.scrollY.number ?? 0
//         )
//     }

//     func querySelector(_ selector: String) -> DOM.Node? {
//         guard let element = jsQuerySelector.callAsFunction(this: jsDocument, arguments: [selector.jsValue]).object else {
//             return nil
//         }
//         return DOM.Node(element)
//     }
// }

private extension DOM.Animation.KeyframeEffect {
    var jsKeyframes: JSValue {
        let object = JSObject()
        object[property] = values.jsValue
        return object.jsValue
        // FIXME EMBEDDED: below does not compile for embedded - test with main, report issue
        // [
        //     property: values.jsValue,
        // ].jsValue
    }

    var jsTiming: JSValue {
        let object = JSObject()
        object["duration"] = duration.jsValue
        object["fill"] = "forwards".jsValue
        if composite != .replace {
            object["composite"] = composite.jsValue
        }

        return object.jsValue
        // FIXME EMBEDDED: below does not compile for embedded - test with main, report issue
        // [
        //     "duration": duration.jsValue,
        //     "fill": "forwards".jsValue,
        //     "composite": composite.rawValue.jsValue,
        // ].jsValue
    }
}

extension DOM.Animation.CompositeOperation {
    var jsValue: JSValue {
        switch self {
        case .replace:
            return "replace".jsValue
        case .add:
            return "add".jsValue
        case .accumulate:
            return "accumulate".jsValue
        }
    }
}
