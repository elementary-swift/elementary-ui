// bridge-js: skip
// NOTICE: This is auto-generated code by BridgeJS from JavaScriptKit,
// DO NOT EDIT.
//
// To update this file, just rebuild your project or run
// `swift package bridge-js`.

@_spi(BridgeJS) import JavaScriptKit

#if arch(wasm32)
@_extern(wasm, module: "bjs", name: "invoke_js_callback_BrowserInterop_14BrowserInteropSd_y")
fileprivate func invoke_js_callback_BrowserInterop_14BrowserInteropSd_y_extern(_ callback: Int32, _ param0: Float64) -> Void
#else
fileprivate func invoke_js_callback_BrowserInterop_14BrowserInteropSd_y_extern(_ callback: Int32, _ param0: Float64) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func invoke_js_callback_BrowserInterop_14BrowserInteropSd_y(_ callback: Int32, _ param0: Float64) -> Void {
    return invoke_js_callback_BrowserInterop_14BrowserInteropSd_y_extern(callback, param0)
}

#if arch(wasm32)
@_extern(wasm, module: "bjs", name: "make_swift_closure_BrowserInterop_14BrowserInteropSd_y")
fileprivate func make_swift_closure_BrowserInterop_14BrowserInteropSd_y_extern(_ boxPtr: UnsafeMutableRawPointer, _ file: UnsafePointer<UInt8>, _ line: UInt32) -> Int32
#else
fileprivate func make_swift_closure_BrowserInterop_14BrowserInteropSd_y_extern(_ boxPtr: UnsafeMutableRawPointer, _ file: UnsafePointer<UInt8>, _ line: UInt32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func make_swift_closure_BrowserInterop_14BrowserInteropSd_y(_ boxPtr: UnsafeMutableRawPointer, _ file: UnsafePointer<UInt8>, _ line: UInt32) -> Int32 {
    return make_swift_closure_BrowserInterop_14BrowserInteropSd_y_extern(boxPtr, file, line)
}

private enum _BJS_Closure_14BrowserInteropSd_y {
    static func bridgeJSLift(_ callbackId: Int32) -> (Double) -> Void {
        let callback = JSObject.bridgeJSLiftParameter(callbackId)
        return { [callback] param0 in
            #if arch(wasm32)
            let callbackValue = callback.bridgeJSLowerParameter()
            let param0Value = param0.bridgeJSLowerParameter()
            invoke_js_callback_BrowserInterop_14BrowserInteropSd_y(callbackValue, param0Value)
            #else
            fatalError("Only available on WebAssembly")
            #endif
        }
    }
}

extension JSTypedClosure where Signature == (Double) -> Void {
    init(fileID: StaticString = #fileID, line: UInt32 = #line, _ body: @escaping (Double) -> Void) {
        self.init(
            makeClosure: make_swift_closure_BrowserInterop_14BrowserInteropSd_y,
            body: body,
            fileID: fileID,
            line: line
        )
    }
}

@_expose(wasm, "invoke_swift_closure_BrowserInterop_14BrowserInteropSd_y")
@_cdecl("invoke_swift_closure_BrowserInterop_14BrowserInteropSd_y")
public func _invoke_swift_closure_BrowserInterop_14BrowserInteropSd_y(_ boxPtr: UnsafeMutableRawPointer, _ param0: Float64) -> Void {
    #if arch(wasm32)
    let closure = Unmanaged<_BridgeJSTypedClosureBox<(Double) -> Void>>.fromOpaque(boxPtr).takeUnretainedValue().closure
    closure(Double.bridgeJSLiftParameter(param0))
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

#if arch(wasm32)
@_extern(wasm, module: "bjs", name: "invoke_js_callback_BrowserInterop_14BrowserInteropy_y")
fileprivate func invoke_js_callback_BrowserInterop_14BrowserInteropy_y_extern(_ callback: Int32) -> Void
#else
fileprivate func invoke_js_callback_BrowserInterop_14BrowserInteropy_y_extern(_ callback: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func invoke_js_callback_BrowserInterop_14BrowserInteropy_y(_ callback: Int32) -> Void {
    return invoke_js_callback_BrowserInterop_14BrowserInteropy_y_extern(callback)
}

#if arch(wasm32)
@_extern(wasm, module: "bjs", name: "make_swift_closure_BrowserInterop_14BrowserInteropy_y")
fileprivate func make_swift_closure_BrowserInterop_14BrowserInteropy_y_extern(_ boxPtr: UnsafeMutableRawPointer, _ file: UnsafePointer<UInt8>, _ line: UInt32) -> Int32
#else
fileprivate func make_swift_closure_BrowserInterop_14BrowserInteropy_y_extern(_ boxPtr: UnsafeMutableRawPointer, _ file: UnsafePointer<UInt8>, _ line: UInt32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func make_swift_closure_BrowserInterop_14BrowserInteropy_y(_ boxPtr: UnsafeMutableRawPointer, _ file: UnsafePointer<UInt8>, _ line: UInt32) -> Int32 {
    return make_swift_closure_BrowserInterop_14BrowserInteropy_y_extern(boxPtr, file, line)
}

private enum _BJS_Closure_14BrowserInteropy_y {
    static func bridgeJSLift(_ callbackId: Int32) -> () -> Void {
        let callback = JSObject.bridgeJSLiftParameter(callbackId)
        return { [callback] in
            #if arch(wasm32)
            let callbackValue = callback.bridgeJSLowerParameter()
            invoke_js_callback_BrowserInterop_14BrowserInteropy_y(callbackValue)
            #else
            fatalError("Only available on WebAssembly")
            #endif
        }
    }
}

extension JSTypedClosure where Signature == () -> Void {
    init(fileID: StaticString = #fileID, line: UInt32 = #line, _ body: @escaping () -> Void) {
        self.init(
            makeClosure: make_swift_closure_BrowserInterop_14BrowserInteropy_y,
            body: body,
            fileID: fileID,
            line: line
        )
    }
}

@_expose(wasm, "invoke_swift_closure_BrowserInterop_14BrowserInteropy_y")
@_cdecl("invoke_swift_closure_BrowserInterop_14BrowserInteropy_y")
public func _invoke_swift_closure_BrowserInterop_14BrowserInteropy_y(_ boxPtr: UnsafeMutableRawPointer) -> Void {
    #if arch(wasm32)
    let closure = Unmanaged<_BridgeJSTypedClosureBox<() -> Void>>.fromOpaque(boxPtr).takeUnretainedValue().closure
    closure()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDocument_body_get")
fileprivate func bjs_JSDocument_body_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSDocument_body_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDocument_body_get(_ self: Int32) -> Int32 {
    return bjs_JSDocument_body_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDocument_createElement")
fileprivate func bjs_JSDocument_createElement_extern(_ self: Int32, _ tagName: Int32) -> Int32
#else
fileprivate func bjs_JSDocument_createElement_extern(_ self: Int32, _ tagName: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDocument_createElement(_ self: Int32, _ tagName: Int32) -> Int32 {
    return bjs_JSDocument_createElement_extern(self, tagName)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDocument_createTextNode")
fileprivate func bjs_JSDocument_createTextNode_extern(_ self: Int32, _ text: Int32) -> Int32
#else
fileprivate func bjs_JSDocument_createTextNode_extern(_ self: Int32, _ text: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDocument_createTextNode(_ self: Int32, _ text: Int32) -> Int32 {
    return bjs_JSDocument_createTextNode_extern(self, text)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDocument_querySelector")
fileprivate func bjs_JSDocument_querySelector_extern(_ self: Int32, _ selector: Int32) -> Int32
#else
fileprivate func bjs_JSDocument_querySelector_extern(_ self: Int32, _ selector: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDocument_querySelector(_ self: Int32, _ selector: Int32) -> Int32 {
    return bjs_JSDocument_querySelector_extern(self, selector)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDocument_addEventListener")
fileprivate func bjs_JSDocument_addEventListener_extern(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void
#else
fileprivate func bjs_JSDocument_addEventListener_extern(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDocument_addEventListener(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void {
    return bjs_JSDocument_addEventListener_extern(self, type, listener)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDocument_removeEventListener")
fileprivate func bjs_JSDocument_removeEventListener_extern(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void
#else
fileprivate func bjs_JSDocument_removeEventListener_extern(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDocument_removeEventListener(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void {
    return bjs_JSDocument_removeEventListener_extern(self, type, listener)
}

func _$JSDocument_body_get(_ self: JSObject) throws(JSException) -> JSElement {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSDocument_body_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSElement.bridgeJSLiftReturn(ret)
}

func _$JSDocument_createElement(_ self: JSObject, _ tagName: String) throws(JSException) -> JSElement {
    let selfValue = self.bridgeJSLowerParameter()
    let tagNameValue = tagName.bridgeJSLowerParameter()
    let ret = bjs_JSDocument_createElement(selfValue, tagNameValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSElement.bridgeJSLiftReturn(ret)
}

func _$JSDocument_createTextNode(_ self: JSObject, _ text: String) throws(JSException) -> JSNode {
    let selfValue = self.bridgeJSLowerParameter()
    let textValue = text.bridgeJSLowerParameter()
    let ret = bjs_JSDocument_createTextNode(selfValue, textValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSNode.bridgeJSLiftReturn(ret)
}

func _$JSDocument_querySelector(_ self: JSObject, _ selector: String) throws(JSException) -> JSElement {
    let selfValue = self.bridgeJSLowerParameter()
    let selectorValue = selector.bridgeJSLowerParameter()
    let ret = bjs_JSDocument_querySelector(selfValue, selectorValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSElement.bridgeJSLiftReturn(ret)
}

func _$JSDocument_addEventListener(_ self: JSObject, _ type: String, _ listener: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let typeValue = type.bridgeJSLowerParameter()
    let listenerValue = listener.bridgeJSLowerParameter()
    bjs_JSDocument_addEventListener(selfValue, typeValue, listenerValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSDocument_removeEventListener(_ self: JSObject, _ type: String, _ listener: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let typeValue = type.bridgeJSLowerParameter()
    let listenerValue = listener.bridgeJSLowerParameter()
    bjs_JSDocument_removeEventListener(selfValue, typeValue, listenerValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSWindow_scrollX_get")
fileprivate func bjs_JSWindow_scrollX_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSWindow_scrollX_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSWindow_scrollX_get(_ self: Int32) -> Float64 {
    return bjs_JSWindow_scrollX_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSWindow_scrollY_get")
fileprivate func bjs_JSWindow_scrollY_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSWindow_scrollY_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSWindow_scrollY_get(_ self: Int32) -> Float64 {
    return bjs_JSWindow_scrollY_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSWindow_getComputedStyle")
fileprivate func bjs_JSWindow_getComputedStyle_extern(_ self: Int32, _ element: Int32) -> Int32
#else
fileprivate func bjs_JSWindow_getComputedStyle_extern(_ self: Int32, _ element: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSWindow_getComputedStyle(_ self: Int32, _ element: Int32) -> Int32 {
    return bjs_JSWindow_getComputedStyle_extern(self, element)
}

func _$JSWindow_scrollX_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSWindow_scrollX_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSWindow_scrollY_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSWindow_scrollY_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSWindow_getComputedStyle(_ self: JSObject, _ element: JSElement) throws(JSException) -> JSCSSStyleDeclaration {
    let selfValue = self.bridgeJSLowerParameter()
    let elementValue = element.bridgeJSLowerParameter()
    let ret = bjs_JSWindow_getComputedStyle(selfValue, elementValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSCSSStyleDeclaration.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSPerformance_now")
fileprivate func bjs_JSPerformance_now_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSPerformance_now_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSPerformance_now(_ self: Int32) -> Float64 {
    return bjs_JSPerformance_now_extern(self)
}

func _$JSPerformance_now(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSPerformance_now(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSNode_textContent_get")
fileprivate func bjs_JSNode_textContent_get_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSNode_textContent_get_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSNode_textContent_get(_ self: Int32) -> Void {
    return bjs_JSNode_textContent_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSNode_textContent_set")
fileprivate func bjs_JSNode_textContent_set_extern(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void
#else
fileprivate func bjs_JSNode_textContent_set_extern(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSNode_textContent_set(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void {
    return bjs_JSNode_textContent_set_extern(self, newValueIsSome, newValueValue)
}

func _$JSNode_textContent_get(_ self: JSObject) throws(JSException) -> Optional<String> {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSNode_textContent_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Optional<String>.bridgeJSLiftReturnFromSideChannel()
}

func _$JSNode_textContent_set(_ self: JSObject, _ newValue: Optional<String>) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let (newValueIsSome, newValueValue) = newValue.bridgeJSLowerParameter()
    bjs_JSNode_textContent_set(selfValue, newValueIsSome, newValueValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_style_get")
fileprivate func bjs_JSElement_style_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSElement_style_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_style_get(_ self: Int32) -> Int32 {
    return bjs_JSElement_style_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_textContent_get")
fileprivate func bjs_JSElement_textContent_get_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSElement_textContent_get_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_textContent_get(_ self: Int32) -> Void {
    return bjs_JSElement_textContent_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_offsetParent_get")
fileprivate func bjs_JSElement_offsetParent_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSElement_offsetParent_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_offsetParent_get(_ self: Int32) -> Int32 {
    return bjs_JSElement_offsetParent_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_textContent_set")
fileprivate func bjs_JSElement_textContent_set_extern(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void
#else
fileprivate func bjs_JSElement_textContent_set_extern(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_textContent_set(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void {
    return bjs_JSElement_textContent_set_extern(self, newValueIsSome, newValueValue)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_setAttribute")
fileprivate func bjs_JSElement_setAttribute_extern(_ self: Int32, _ name: Int32, _ value: Int32) -> Void
#else
fileprivate func bjs_JSElement_setAttribute_extern(_ self: Int32, _ name: Int32, _ value: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_setAttribute(_ self: Int32, _ name: Int32, _ value: Int32) -> Void {
    return bjs_JSElement_setAttribute_extern(self, name, value)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_removeAttribute")
fileprivate func bjs_JSElement_removeAttribute_extern(_ self: Int32, _ name: Int32) -> Void
#else
fileprivate func bjs_JSElement_removeAttribute_extern(_ self: Int32, _ name: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_removeAttribute(_ self: Int32, _ name: Int32) -> Void {
    return bjs_JSElement_removeAttribute_extern(self, name)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_appendChild")
fileprivate func bjs_JSElement_appendChild_extern(_ self: Int32, _ child: Int32) -> Void
#else
fileprivate func bjs_JSElement_appendChild_extern(_ self: Int32, _ child: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_appendChild(_ self: Int32, _ child: Int32) -> Void {
    return bjs_JSElement_appendChild_extern(self, child)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_removeChild")
fileprivate func bjs_JSElement_removeChild_extern(_ self: Int32, _ child: Int32) -> Void
#else
fileprivate func bjs_JSElement_removeChild_extern(_ self: Int32, _ child: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_removeChild(_ self: Int32, _ child: Int32) -> Void {
    return bjs_JSElement_removeChild_extern(self, child)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_getBoundingClientRect")
fileprivate func bjs_JSElement_getBoundingClientRect_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSElement_getBoundingClientRect_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_getBoundingClientRect(_ self: Int32) -> Int32 {
    return bjs_JSElement_getBoundingClientRect_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_addEventListener")
fileprivate func bjs_JSElement_addEventListener_extern(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void
#else
fileprivate func bjs_JSElement_addEventListener_extern(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_addEventListener(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void {
    return bjs_JSElement_addEventListener_extern(self, type, listener)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_removeEventListener")
fileprivate func bjs_JSElement_removeEventListener_extern(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void
#else
fileprivate func bjs_JSElement_removeEventListener_extern(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_removeEventListener(_ self: Int32, _ type: Int32, _ listener: Int32) -> Void {
    return bjs_JSElement_removeEventListener_extern(self, type, listener)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_focus")
fileprivate func bjs_JSElement_focus_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSElement_focus_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_focus(_ self: Int32) -> Void {
    return bjs_JSElement_focus_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_blur")
fileprivate func bjs_JSElement_blur_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSElement_blur_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_blur(_ self: Int32) -> Void {
    return bjs_JSElement_blur_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSElement_animate")
fileprivate func bjs_JSElement_animate_extern(_ self: Int32, _ keyframes: Int32, _ options: Int32) -> Int32
#else
fileprivate func bjs_JSElement_animate_extern(_ self: Int32, _ keyframes: Int32, _ options: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSElement_animate(_ self: Int32, _ keyframes: Int32, _ options: Int32) -> Int32 {
    return bjs_JSElement_animate_extern(self, keyframes, options)
}

func _$JSElement_style_get(_ self: JSObject) throws(JSException) -> JSCSSStyleDeclaration {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSElement_style_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSCSSStyleDeclaration.bridgeJSLiftReturn(ret)
}

func _$JSElement_textContent_get(_ self: JSObject) throws(JSException) -> Optional<String> {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSElement_textContent_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Optional<String>.bridgeJSLiftReturnFromSideChannel()
}

func _$JSElement_offsetParent_get(_ self: JSObject) throws(JSException) -> JSElement {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSElement_offsetParent_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSElement.bridgeJSLiftReturn(ret)
}

func _$JSElement_textContent_set(_ self: JSObject, _ newValue: Optional<String>) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let (newValueIsSome, newValueValue) = newValue.bridgeJSLowerParameter()
    bjs_JSElement_textContent_set(selfValue, newValueIsSome, newValueValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_setAttribute(_ self: JSObject, _ name: String, _ value: String) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let nameValue = name.bridgeJSLowerParameter()
    let valueValue = value.bridgeJSLowerParameter()
    bjs_JSElement_setAttribute(selfValue, nameValue, valueValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_removeAttribute(_ self: JSObject, _ name: String) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let nameValue = name.bridgeJSLowerParameter()
    bjs_JSElement_removeAttribute(selfValue, nameValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_appendChild(_ self: JSObject, _ child: JSNode) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let childValue = child.bridgeJSLowerParameter()
    bjs_JSElement_appendChild(selfValue, childValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_removeChild(_ self: JSObject, _ child: JSNode) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let childValue = child.bridgeJSLowerParameter()
    bjs_JSElement_removeChild(selfValue, childValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_getBoundingClientRect(_ self: JSObject) throws(JSException) -> JSDOMRect {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSElement_getBoundingClientRect(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSDOMRect.bridgeJSLiftReturn(ret)
}

func _$JSElement_addEventListener(_ self: JSObject, _ type: String, _ listener: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let typeValue = type.bridgeJSLowerParameter()
    let listenerValue = listener.bridgeJSLowerParameter()
    bjs_JSElement_addEventListener(selfValue, typeValue, listenerValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_removeEventListener(_ self: JSObject, _ type: String, _ listener: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let typeValue = type.bridgeJSLowerParameter()
    let listenerValue = listener.bridgeJSLowerParameter()
    bjs_JSElement_removeEventListener(selfValue, typeValue, listenerValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_focus(_ self: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSElement_focus(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_blur(_ self: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSElement_blur(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSElement_animate(_ self: JSObject, _ keyframes: JSObject, _ options: JSObject) throws(JSException) -> JSAnimation {
    let selfValue = self.bridgeJSLowerParameter()
    let keyframesValue = keyframes.bridgeJSLowerParameter()
    let optionsValue = options.bridgeJSLowerParameter()
    let ret = bjs_JSElement_animate(selfValue, keyframesValue, optionsValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSAnimation.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSCSSStyleDeclaration_getPropertyValue")
fileprivate func bjs_JSCSSStyleDeclaration_getPropertyValue_extern(_ self: Int32, _ name: Int32) -> Int32
#else
fileprivate func bjs_JSCSSStyleDeclaration_getPropertyValue_extern(_ self: Int32, _ name: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSCSSStyleDeclaration_getPropertyValue(_ self: Int32, _ name: Int32) -> Int32 {
    return bjs_JSCSSStyleDeclaration_getPropertyValue_extern(self, name)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSCSSStyleDeclaration_setProperty")
fileprivate func bjs_JSCSSStyleDeclaration_setProperty_extern(_ self: Int32, _ name: Int32, _ value: Int32) -> Void
#else
fileprivate func bjs_JSCSSStyleDeclaration_setProperty_extern(_ self: Int32, _ name: Int32, _ value: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSCSSStyleDeclaration_setProperty(_ self: Int32, _ name: Int32, _ value: Int32) -> Void {
    return bjs_JSCSSStyleDeclaration_setProperty_extern(self, name, value)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSCSSStyleDeclaration_removeProperty")
fileprivate func bjs_JSCSSStyleDeclaration_removeProperty_extern(_ self: Int32, _ name: Int32) -> Void
#else
fileprivate func bjs_JSCSSStyleDeclaration_removeProperty_extern(_ self: Int32, _ name: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSCSSStyleDeclaration_removeProperty(_ self: Int32, _ name: Int32) -> Void {
    return bjs_JSCSSStyleDeclaration_removeProperty_extern(self, name)
}

func _$JSCSSStyleDeclaration_getPropertyValue(_ self: JSObject, _ name: String) throws(JSException) -> String {
    let selfValue = self.bridgeJSLowerParameter()
    let nameValue = name.bridgeJSLowerParameter()
    let ret = bjs_JSCSSStyleDeclaration_getPropertyValue(selfValue, nameValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return String.bridgeJSLiftReturn(ret)
}

func _$JSCSSStyleDeclaration_setProperty(_ self: JSObject, _ name: String, _ value: String) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let nameValue = name.bridgeJSLowerParameter()
    let valueValue = value.bridgeJSLowerParameter()
    bjs_JSCSSStyleDeclaration_setProperty(selfValue, nameValue, valueValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSCSSStyleDeclaration_removeProperty(_ self: JSObject, _ name: String) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let nameValue = name.bridgeJSLowerParameter()
    bjs_JSCSSStyleDeclaration_removeProperty(selfValue, nameValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDOMRect_x_get")
fileprivate func bjs_JSDOMRect_x_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSDOMRect_x_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDOMRect_x_get(_ self: Int32) -> Float64 {
    return bjs_JSDOMRect_x_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDOMRect_y_get")
fileprivate func bjs_JSDOMRect_y_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSDOMRect_y_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDOMRect_y_get(_ self: Int32) -> Float64 {
    return bjs_JSDOMRect_y_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDOMRect_width_get")
fileprivate func bjs_JSDOMRect_width_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSDOMRect_width_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDOMRect_width_get(_ self: Int32) -> Float64 {
    return bjs_JSDOMRect_width_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSDOMRect_height_get")
fileprivate func bjs_JSDOMRect_height_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSDOMRect_height_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSDOMRect_height_get(_ self: Int32) -> Float64 {
    return bjs_JSDOMRect_height_get_extern(self)
}

func _$JSDOMRect_x_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSDOMRect_x_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSDOMRect_y_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSDOMRect_y_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSDOMRect_width_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSDOMRect_width_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSDOMRect_height_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSDOMRect_height_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimation_effect_get")
fileprivate func bjs_JSAnimation_effect_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSAnimation_effect_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimation_effect_get(_ self: Int32) -> Int32 {
    return bjs_JSAnimation_effect_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimation_currentTime_set")
fileprivate func bjs_JSAnimation_currentTime_set_extern(_ self: Int32, _ newValue: Float64) -> Void
#else
fileprivate func bjs_JSAnimation_currentTime_set_extern(_ self: Int32, _ newValue: Float64) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimation_currentTime_set(_ self: Int32, _ newValue: Float64) -> Void {
    return bjs_JSAnimation_currentTime_set_extern(self, newValue)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimation_onfinish_set")
fileprivate func bjs_JSAnimation_onfinish_set_extern(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void
#else
fileprivate func bjs_JSAnimation_onfinish_set_extern(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimation_onfinish_set(_ self: Int32, _ newValueIsSome: Int32, _ newValueValue: Int32) -> Void {
    return bjs_JSAnimation_onfinish_set_extern(self, newValueIsSome, newValueValue)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimation_persist")
fileprivate func bjs_JSAnimation_persist_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSAnimation_persist_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimation_persist(_ self: Int32) -> Void {
    return bjs_JSAnimation_persist_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimation_pause")
fileprivate func bjs_JSAnimation_pause_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSAnimation_pause_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimation_pause(_ self: Int32) -> Void {
    return bjs_JSAnimation_pause_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimation_play")
fileprivate func bjs_JSAnimation_play_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSAnimation_play_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimation_play(_ self: Int32) -> Void {
    return bjs_JSAnimation_play_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimation_cancel")
fileprivate func bjs_JSAnimation_cancel_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSAnimation_cancel_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimation_cancel(_ self: Int32) -> Void {
    return bjs_JSAnimation_cancel_extern(self)
}

func _$JSAnimation_effect_get(_ self: JSObject) throws(JSException) -> JSAnimationEffect {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSAnimation_effect_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSAnimationEffect.bridgeJSLiftReturn(ret)
}

func _$JSAnimation_currentTime_set(_ self: JSObject, _ newValue: Double) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let newValueValue = newValue.bridgeJSLowerParameter()
    bjs_JSAnimation_currentTime_set(selfValue, newValueValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSAnimation_onfinish_set(_ self: JSObject, _ newValue: Optional<JSObject>) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let (newValueIsSome, newValueValue) = newValue.bridgeJSLowerParameter()
    bjs_JSAnimation_onfinish_set(selfValue, newValueIsSome, newValueValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSAnimation_persist(_ self: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSAnimation_persist(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSAnimation_pause(_ self: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSAnimation_pause(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSAnimation_play(_ self: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSAnimation_play(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSAnimation_cancel(_ self: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSAnimation_cancel(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimationEffect_setKeyframes")
fileprivate func bjs_JSAnimationEffect_setKeyframes_extern(_ self: Int32, _ keyframes: Int32) -> Void
#else
fileprivate func bjs_JSAnimationEffect_setKeyframes_extern(_ self: Int32, _ keyframes: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimationEffect_setKeyframes(_ self: Int32, _ keyframes: Int32) -> Void {
    return bjs_JSAnimationEffect_setKeyframes_extern(self, keyframes)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSAnimationEffect_updateTiming")
fileprivate func bjs_JSAnimationEffect_updateTiming_extern(_ self: Int32, _ timing: Int32) -> Void
#else
fileprivate func bjs_JSAnimationEffect_updateTiming_extern(_ self: Int32, _ timing: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSAnimationEffect_updateTiming(_ self: Int32, _ timing: Int32) -> Void {
    return bjs_JSAnimationEffect_updateTiming_extern(self, timing)
}

func _$JSAnimationEffect_setKeyframes(_ self: JSObject, _ keyframes: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let keyframesValue = keyframes.bridgeJSLowerParameter()
    bjs_JSAnimationEffect_setKeyframes(selfValue, keyframesValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

func _$JSAnimationEffect_updateTiming(_ self: JSObject, _ timing: JSObject) throws(JSException) -> Void {
    let selfValue = self.bridgeJSLowerParameter()
    let timingValue = timing.bridgeJSLowerParameter()
    bjs_JSAnimationEffect_updateTiming(selfValue, timingValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSEvent_type_get")
fileprivate func bjs_JSEvent_type_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSEvent_type_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSEvent_type_get(_ self: Int32) -> Int32 {
    return bjs_JSEvent_type_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSEvent_target_get")
fileprivate func bjs_JSEvent_target_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSEvent_target_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSEvent_target_get(_ self: Int32) -> Int32 {
    return bjs_JSEvent_target_get_extern(self)
}

func _$JSEvent_type_get(_ self: JSObject) throws(JSException) -> String {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSEvent_type_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return String.bridgeJSLiftReturn(ret)
}

func _$JSEvent_target_get(_ self: JSObject) throws(JSException) -> JSObject {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSEvent_target_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSObject.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSKeyboardEvent_key_get")
fileprivate func bjs_JSKeyboardEvent_key_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSKeyboardEvent_key_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSKeyboardEvent_key_get(_ self: Int32) -> Int32 {
    return bjs_JSKeyboardEvent_key_get_extern(self)
}

func _$JSKeyboardEvent_key_get(_ self: JSObject) throws(JSException) -> String {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSKeyboardEvent_key_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return String.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_altKey_get")
fileprivate func bjs_JSMouseEvent_altKey_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSMouseEvent_altKey_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_altKey_get(_ self: Int32) -> Int32 {
    return bjs_JSMouseEvent_altKey_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_button_get")
fileprivate func bjs_JSMouseEvent_button_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSMouseEvent_button_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_button_get(_ self: Int32) -> Int32 {
    return bjs_JSMouseEvent_button_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_buttons_get")
fileprivate func bjs_JSMouseEvent_buttons_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSMouseEvent_buttons_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_buttons_get(_ self: Int32) -> Int32 {
    return bjs_JSMouseEvent_buttons_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_clientX_get")
fileprivate func bjs_JSMouseEvent_clientX_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_clientX_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_clientX_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_clientX_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_clientY_get")
fileprivate func bjs_JSMouseEvent_clientY_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_clientY_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_clientY_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_clientY_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_ctrlKey_get")
fileprivate func bjs_JSMouseEvent_ctrlKey_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSMouseEvent_ctrlKey_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_ctrlKey_get(_ self: Int32) -> Int32 {
    return bjs_JSMouseEvent_ctrlKey_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_metaKey_get")
fileprivate func bjs_JSMouseEvent_metaKey_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSMouseEvent_metaKey_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_metaKey_get(_ self: Int32) -> Int32 {
    return bjs_JSMouseEvent_metaKey_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_movementX_get")
fileprivate func bjs_JSMouseEvent_movementX_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_movementX_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_movementX_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_movementX_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_movementY_get")
fileprivate func bjs_JSMouseEvent_movementY_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_movementY_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_movementY_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_movementY_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_offsetX_get")
fileprivate func bjs_JSMouseEvent_offsetX_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_offsetX_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_offsetX_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_offsetX_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_offsetY_get")
fileprivate func bjs_JSMouseEvent_offsetY_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_offsetY_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_offsetY_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_offsetY_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_pageX_get")
fileprivate func bjs_JSMouseEvent_pageX_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_pageX_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_pageX_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_pageX_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_pageY_get")
fileprivate func bjs_JSMouseEvent_pageY_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_pageY_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_pageY_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_pageY_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_screenX_get")
fileprivate func bjs_JSMouseEvent_screenX_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_screenX_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_screenX_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_screenX_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_screenY_get")
fileprivate func bjs_JSMouseEvent_screenY_get_extern(_ self: Int32) -> Float64
#else
fileprivate func bjs_JSMouseEvent_screenY_get_extern(_ self: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_screenY_get(_ self: Int32) -> Float64 {
    return bjs_JSMouseEvent_screenY_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSMouseEvent_shiftKey_get")
fileprivate func bjs_JSMouseEvent_shiftKey_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSMouseEvent_shiftKey_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSMouseEvent_shiftKey_get(_ self: Int32) -> Int32 {
    return bjs_JSMouseEvent_shiftKey_get_extern(self)
}

func _$JSMouseEvent_altKey_get(_ self: JSObject) throws(JSException) -> Bool {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_altKey_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Bool.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_button_get(_ self: JSObject) throws(JSException) -> Int {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_button_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Int.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_buttons_get(_ self: JSObject) throws(JSException) -> Int {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_buttons_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Int.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_clientX_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_clientX_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_clientY_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_clientY_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_ctrlKey_get(_ self: JSObject) throws(JSException) -> Bool {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_ctrlKey_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Bool.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_metaKey_get(_ self: JSObject) throws(JSException) -> Bool {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_metaKey_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Bool.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_movementX_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_movementX_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_movementY_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_movementY_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_offsetX_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_offsetX_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_offsetY_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_offsetY_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_pageX_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_pageX_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_pageY_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_pageY_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_screenX_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_screenX_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_screenY_get(_ self: JSObject) throws(JSException) -> Double {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_screenY_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

func _$JSMouseEvent_shiftKey_get(_ self: JSObject) throws(JSException) -> Bool {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSMouseEvent_shiftKey_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Bool.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSInputEvent_data_get")
fileprivate func bjs_JSInputEvent_data_get_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSInputEvent_data_get_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSInputEvent_data_get(_ self: Int32) -> Void {
    return bjs_JSInputEvent_data_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_JSInputEvent_target_get")
fileprivate func bjs_JSInputEvent_target_get_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSInputEvent_target_get_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSInputEvent_target_get(_ self: Int32) -> Int32 {
    return bjs_JSInputEvent_target_get_extern(self)
}

func _$JSInputEvent_data_get(_ self: JSObject) throws(JSException) -> Optional<String> {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSInputEvent_data_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Optional<String>.bridgeJSLiftReturnFromSideChannel()
}

func _$JSInputEvent_target_get(_ self: JSObject) throws(JSException) -> JSObject {
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSInputEvent_target_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSObject.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_window_get")
fileprivate func bjs_window_get_extern() -> Int32
#else
fileprivate func bjs_window_get_extern() -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_window_get() -> Int32 {
    return bjs_window_get_extern()
}

func _$window_get() throws(JSException) -> JSWindow {
    let ret = bjs_window_get()
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSWindow.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_document_get")
fileprivate func bjs_document_get_extern() -> Int32
#else
fileprivate func bjs_document_get_extern() -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_document_get() -> Int32 {
    return bjs_document_get_extern()
}

func _$document_get() throws(JSException) -> JSDocument {
    let ret = bjs_document_get()
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSDocument.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_performance_get")
fileprivate func bjs_performance_get_extern() -> Int32
#else
fileprivate func bjs_performance_get_extern() -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_performance_get() -> Int32 {
    return bjs_performance_get_extern()
}

func _$performance_get() throws(JSException) -> JSPerformance {
    let ret = bjs_performance_get()
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSPerformance.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_requestAnimationFrame")
fileprivate func bjs_requestAnimationFrame_extern(_ callback: Int32) -> Float64
#else
fileprivate func bjs_requestAnimationFrame_extern(_ callback: Int32) -> Float64 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_requestAnimationFrame(_ callback: Int32) -> Float64 {
    return bjs_requestAnimationFrame_extern(callback)
}

func _$requestAnimationFrame(_ callback: @escaping (Double) -> Void) throws(JSException) -> Double {
    let callback = JSTypedClosure<(Double) -> Void>(callback)
    let callbackFuncRef = callback.bridgeJSLowerParameter()
    let ret = withExtendedLifetime((callback)) {
        bjs_requestAnimationFrame(callbackFuncRef)
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Double.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_cancelAnimationFrame")
fileprivate func bjs_cancelAnimationFrame_extern(_ handle: Float64) -> Void
#else
fileprivate func bjs_cancelAnimationFrame_extern(_ handle: Float64) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_cancelAnimationFrame(_ handle: Float64) -> Void {
    return bjs_cancelAnimationFrame_extern(handle)
}

func _$cancelAnimationFrame(_ handle: Double) throws(JSException) -> Void {
    let handleValue = handle.bridgeJSLowerParameter()
    bjs_cancelAnimationFrame(handleValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_queueMicrotask")
fileprivate func bjs_queueMicrotask_extern(_ callback: Int32) -> Void
#else
fileprivate func bjs_queueMicrotask_extern(_ callback: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_queueMicrotask(_ callback: Int32) -> Void {
    return bjs_queueMicrotask_extern(callback)
}

func _$queueMicrotask(_ callback: @escaping () -> Void) throws(JSException) -> Void {
    let callback = JSTypedClosure<() -> Void>(callback)
    let callbackFuncRef = callback.bridgeJSLowerParameter()
    withExtendedLifetime((callback)) {
        bjs_queueMicrotask(callbackFuncRef)
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "BrowserInterop", name: "bjs_setTimeout")
fileprivate func bjs_setTimeout_extern(_ callback: Int32, _ timeout: Float64) -> Void
#else
fileprivate func bjs_setTimeout_extern(_ callback: Int32, _ timeout: Float64) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_setTimeout(_ callback: Int32, _ timeout: Float64) -> Void {
    return bjs_setTimeout_extern(callback, timeout)
}

func _$setTimeout(_ callback: @escaping () -> Void, _ timeout: Double) throws(JSException) -> Void {
    let callback = JSTypedClosure<() -> Void>(callback)
    let callbackFuncRef = callback.bridgeJSLowerParameter()
    let timeoutValue = timeout.bridgeJSLowerParameter()
    withExtendedLifetime((callback)) {
        bjs_setTimeout(callbackFuncRef, timeoutValue)
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
}