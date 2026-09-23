// bridge-js: skip
// swift-format-ignore-file
// NOTICE: This is auto-generated code by BridgeJS from JavaScriptKit,
// DO NOT EDIT.
//
// To update this file, just rebuild your project or run
// `swift package bridge-js`.

@_spi(BridgeJS) import JavaScriptKit

extension JSShadowRootInit: _BridgedSwiftStruct {
    @_spi(BridgeJS) @_transparent public static func bridgeJSStackPop() -> JSShadowRootInit {
        let mode = String.bridgeJSStackPop()
        return JSShadowRootInit(mode: mode)
    }

    @_spi(BridgeJS) @_transparent public consuming func bridgeJSStackPush() {
        self.mode.bridgeJSStackPush()
    }

    init(unsafelyCopying jsObject: JSObject) {
        _bjs_struct_lower_JSShadowRootInit(jsObject.bridgeJSLowerParameter())
        self = Self.bridgeJSStackPop()
    }

    func toJSObject() -> JSObject {
        let __bjs_self = self
        __bjs_self.bridgeJSStackPush()
        return JSObject(id: UInt32(bitPattern: _bjs_struct_lift_JSShadowRootInit()))
    }
}

#if arch(wasm32)
@_extern(wasm, module: "bjs", name: "swift_js_struct_lower_JSShadowRootInit")
fileprivate func _bjs_struct_lower_JSShadowRootInit_extern(_ objectId: Int32) -> Void
#else
fileprivate func _bjs_struct_lower_JSShadowRootInit_extern(_ objectId: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func _bjs_struct_lower_JSShadowRootInit(_ objectId: Int32) -> Void {
    return _bjs_struct_lower_JSShadowRootInit_extern(objectId)
}

#if arch(wasm32)
@_extern(wasm, module: "bjs", name: "swift_js_struct_lift_JSShadowRootInit")
fileprivate func _bjs_struct_lift_JSShadowRootInit_extern() -> Int32
#else
fileprivate func _bjs_struct_lift_JSShadowRootInit_extern() -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func _bjs_struct_lift_JSShadowRootInit() -> Int32 {
    return _bjs_struct_lift_JSShadowRootInit_extern()
}

@_expose(wasm, "bjs_CustomElementImplementation_construct")
@_cdecl("bjs_CustomElementImplementation_construct")
public func _bjs_CustomElementImplementation_construct(_ _self: UnsafeMutableRawPointer, _ element: Int32) -> Void {
    #if arch(wasm32)
    do {
        try CustomElementImplementation.bridgeJSLiftParameter(_self).construct(element: JSHTMLElement.bridgeJSLiftParameter(element))
    } catch let error {
        if let error = error.thrownValue.object {
            withExtendedLifetime(error) {
                _swift_js_throw(Int32(bitPattern: $0.id))
            }
        } else {
            let jsError = JSError(message: error.description)
            withExtendedLifetime(jsError.jsObject) {
                _swift_js_throw(Int32(bitPattern: $0.id))
            }
        }
        return
    }
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_CustomElementImplementation_connect")
@_cdecl("bjs_CustomElementImplementation_connect")
public func _bjs_CustomElementImplementation_connect(_ _self: UnsafeMutableRawPointer, _ element: Int32) -> Void {
    #if arch(wasm32)
    do {
        try CustomElementImplementation.bridgeJSLiftParameter(_self).connect(element: JSHTMLElement.bridgeJSLiftParameter(element))
    } catch let error {
        if let error = error.thrownValue.object {
            withExtendedLifetime(error) {
                _swift_js_throw(Int32(bitPattern: $0.id))
            }
        } else {
            let jsError = JSError(message: error.description)
            withExtendedLifetime(jsError.jsObject) {
                _swift_js_throw(Int32(bitPattern: $0.id))
            }
        }
        return
    }
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_CustomElementImplementation_destruct")
@_cdecl("bjs_CustomElementImplementation_destruct")
public func _bjs_CustomElementImplementation_destruct(_ _self: UnsafeMutableRawPointer, _ element: Int32) -> Void {
    #if arch(wasm32)
    CustomElementImplementation.bridgeJSLiftParameter(_self).destruct(element: JSHTMLElement.bridgeJSLiftParameter(element))
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_CustomElementImplementation_setAttribute")
@_cdecl("bjs_CustomElementImplementation_setAttribute")
public func _bjs_CustomElementImplementation_setAttribute(_ _self: UnsafeMutableRawPointer, _ element: Int32, _ nameBytes: Int32, _ nameLength: Int32, _ valueIsSome: Int32, _ valueBytes: Int32, _ valueLength: Int32) -> Void {
    #if arch(wasm32)
    CustomElementImplementation.bridgeJSLiftParameter(_self).setAttribute(element: JSHTMLElement.bridgeJSLiftParameter(element), name: String.bridgeJSLiftParameter(nameBytes, nameLength), value: Optional<String>.bridgeJSLiftParameter(valueIsSome, valueBytes, valueLength))
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_CustomElementImplementation_deinit")
@_cdecl("bjs_CustomElementImplementation_deinit")
public func _bjs_CustomElementImplementation_deinit(_ pointer: UnsafeMutableRawPointer) -> Void {
    #if arch(wasm32)
    Unmanaged<CustomElementImplementation>.fromOpaque(pointer).release()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

extension CustomElementImplementation: ConvertibleToJSValue, _BridgedSwiftHeapObject, _BridgedSwiftProtocolExportable {
    var jsValue: JSValue {
        return .object(JSObject(id: UInt32(bitPattern: _bjs_CustomElementImplementation_wrap(Unmanaged.passRetained(self).toOpaque()))))
    }
    consuming func bridgeJSLowerAsProtocolReturn() -> Int32 {
        _bjs_CustomElementImplementation_wrap(Unmanaged.passRetained(self).toOpaque())
    }
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_CustomElementImplementation_wrap")
fileprivate func _bjs_CustomElementImplementation_wrap_extern(_ pointer: UnsafeMutableRawPointer) -> Int32
#else
fileprivate func _bjs_CustomElementImplementation_wrap_extern(_ pointer: UnsafeMutableRawPointer) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func _bjs_CustomElementImplementation_wrap(_ pointer: UnsafeMutableRawPointer) -> Int32 {
    return _bjs_CustomElementImplementation_wrap_extern(pointer)
}

extension JSShadowRootInit: BridgedSwiftGenericBridgeable {
    @_spi(BridgeJS) public static let bridgeJSTypeHandle = JSShadowRootInit.bridgeJSMakeTypeHandle()
}

extension CustomElementImplementation: BridgedSwiftGenericBridgeable {
    @_spi(BridgeJS) public static let bridgeJSTypeHandle = CustomElementImplementation.bridgeJSMakeTypeHandle()
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_defineCustomElement")
fileprivate func bjs_defineCustomElement_extern(_ nameBytes: Int32, _ nameLength: Int32, _ shadowDOMBytes: Int32, _ shadowDOMLength: Int32, _ implementation: UnsafeMutableRawPointer) -> Void
#else
fileprivate func bjs_defineCustomElement_extern(_ nameBytes: Int32, _ nameLength: Int32, _ shadowDOMBytes: Int32, _ shadowDOMLength: Int32, _ implementation: UnsafeMutableRawPointer) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_defineCustomElement(_ nameBytes: Int32, _ nameLength: Int32, _ shadowDOMBytes: Int32, _ shadowDOMLength: Int32, _ implementation: UnsafeMutableRawPointer) -> Void {
    return bjs_defineCustomElement_extern(nameBytes, nameLength, shadowDOMBytes, shadowDOMLength, implementation)
}

func _$defineCustomElement(_ name: String, _ shadowDOM: String, _ observedAttributes: [String], _ implementation: CustomElementImplementation) throws(JSException) -> Void {
    name.bridgeJSWithLoweredParameter { (nameBytes, nameLength) in
        shadowDOM.bridgeJSWithLoweredParameter { (shadowDOMBytes, shadowDOMLength) in
            let implementationPointer = implementation.bridgeJSLowerParameter()
            let _ = observedAttributes.bridgeJSLowerParameter()
            bjs_defineCustomElement(nameBytes, nameLength, shadowDOMBytes, shadowDOMLength, implementationPointer)
        }
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_JSHTMLElement_shadowRoot_get")
fileprivate func bjs_JSHTMLElement_shadowRoot_get_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSHTMLElement_shadowRoot_get_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSHTMLElement_shadowRoot_get(_ self: Int32) -> Void {
    return bjs_JSHTMLElement_shadowRoot_get_extern(self)
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_JSHTMLElement_attachShadow")
fileprivate func bjs_JSHTMLElement_attachShadow_extern(_ self: Int32) -> Int32
#else
fileprivate func bjs_JSHTMLElement_attachShadow_extern(_ self: Int32) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSHTMLElement_attachShadow(_ self: Int32) -> Int32 {
    return bjs_JSHTMLElement_attachShadow_extern(self)
}

func _$JSHTMLElement_shadowRoot_get(_ self: JSObject) throws(JSException) -> Optional<JSShadowRoot> {
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSHTMLElement_shadowRoot_get(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Optional<JSShadowRoot>.bridgeJSLiftReturn()
}

func _$JSHTMLElement_attachShadow(_ self: JSObject, _ options: JSShadowRootInit) throws(JSException) -> JSShadowRoot {
    let _ = options.bridgeJSLowerParameter()
    let selfValue = self.bridgeJSLowerParameter()
    let ret = bjs_JSHTMLElement_attachShadow(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSShadowRoot.bridgeJSLiftReturn(ret)
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_JSShadowRoot_adoptedStyleSheets_set")
fileprivate func bjs_JSShadowRoot_adoptedStyleSheets_set_extern(_ self: Int32) -> Void
#else
fileprivate func bjs_JSShadowRoot_adoptedStyleSheets_set_extern(_ self: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSShadowRoot_adoptedStyleSheets_set(_ self: Int32) -> Void {
    return bjs_JSShadowRoot_adoptedStyleSheets_set_extern(self)
}

func _$JSShadowRoot_adoptedStyleSheets_set(_ self: JSObject, _ newValue: [JSCSSStyleSheet]) throws(JSException) -> Void {
    let _ = newValue.bridgeJSLowerParameter()
    let selfValue = self.bridgeJSLowerParameter()
    bjs_JSShadowRoot_adoptedStyleSheets_set(selfValue)
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_JSCSSStyleSheet_init")
fileprivate func bjs_JSCSSStyleSheet_init_extern() -> Int32
#else
fileprivate func bjs_JSCSSStyleSheet_init_extern() -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSCSSStyleSheet_init() -> Int32 {
    return bjs_JSCSSStyleSheet_init_extern()
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_JSCSSStyleSheet_replaceSync")
fileprivate func bjs_JSCSSStyleSheet_replaceSync_extern(_ self: Int32, _ cssBytes: Int32, _ cssLength: Int32) -> Void
#else
fileprivate func bjs_JSCSSStyleSheet_replaceSync_extern(_ self: Int32, _ cssBytes: Int32, _ cssLength: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSCSSStyleSheet_replaceSync(_ self: Int32, _ cssBytes: Int32, _ cssLength: Int32) -> Void {
    return bjs_JSCSSStyleSheet_replaceSync_extern(self, cssBytes, cssLength)
}

func _$JSCSSStyleSheet_init() throws(JSException) -> JSObject {
    let ret = bjs_JSCSSStyleSheet_init()
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSObject.bridgeJSLiftReturn(ret)
}

func _$JSCSSStyleSheet_replaceSync(_ self: JSObject, _ css: String) throws(JSException) -> Void {
    css.bridgeJSWithLoweredParameter { (cssBytes, cssLength) in
        let selfValue = self.bridgeJSLowerParameter()
        bjs_JSCSSStyleSheet_replaceSync(selfValue, cssBytes, cssLength)
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
}

#if arch(wasm32)
@_extern(wasm, module: "bjs", name: "bjs_ElementaryWebComponents_register_type_handles")
fileprivate func _bjs_ElementaryWebComponents_register_type_handles_extern(_ base: UnsafePointer<Int32>?, _ count: Int32)

@_expose(wasm, "bjs_ElementaryWebComponents_register_type_handles")
public func _bjs_ElementaryWebComponents_register_type_handles() {
    let typeIds: [Int32] = [
        JSShadowRootInit.bridgeJSTypeID,
        CustomElementImplementation.bridgeJSTypeID,
    ]
    typeIds.withUnsafeBufferPointer { buffer in
        _bjs_ElementaryWebComponents_register_type_handles_extern(buffer.baseAddress, Int32(buffer.count))
    }
}
#endif