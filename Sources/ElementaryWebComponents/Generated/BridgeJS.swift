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

@_expose(wasm, "bjs_CustomElementBridge_connect")
@_cdecl("bjs_CustomElementBridge_connect")
public func _bjs_CustomElementBridge_connect(_ _self: UnsafeMutableRawPointer, _ element: Int32) -> Void {
    #if arch(wasm32)
    let element = JSHTMLElement.bridgeJSLiftParameter(element)
    let _self = CustomElementBridge.bridgeJSLiftParameter(_self)
    do {
        try _self.connect(element: element)
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

@_expose(wasm, "bjs_CustomElementBridge_disconnect")
@_cdecl("bjs_CustomElementBridge_disconnect")
public func _bjs_CustomElementBridge_disconnect(_ _self: UnsafeMutableRawPointer, _ element: Int32) -> Void {
    #if arch(wasm32)
    let element = JSHTMLElement.bridgeJSLiftParameter(element)
    let _self = CustomElementBridge.bridgeJSLiftParameter(_self)
    _self.disconnect(element: element)
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_CustomElementBridge_setAttribute")
@_cdecl("bjs_CustomElementBridge_setAttribute")
public func _bjs_CustomElementBridge_setAttribute(_ _self: UnsafeMutableRawPointer, _ element: Int32, _ nameBytes: Int32, _ nameLength: Int32, _ valueIsSome: Int32, _ valueBytes: Int32, _ valueLength: Int32) -> Void {
    #if arch(wasm32)
    let value = Optional<String>.bridgeJSLiftParameter(valueIsSome, valueBytes, valueLength)
    let name = String.bridgeJSLiftParameter(nameBytes, nameLength)
    let element = JSHTMLElement.bridgeJSLiftParameter(element)
    let _self = CustomElementBridge.bridgeJSLiftParameter(_self)
    _self.setAttribute(element: element, name: name, value: value)
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_CustomElementBridge_observedAttributes_get")
@_cdecl("bjs_CustomElementBridge_observedAttributes_get")
public func _bjs_CustomElementBridge_observedAttributes_get(_ _self: UnsafeMutableRawPointer) -> Void {
    #if arch(wasm32)
    let _self = CustomElementBridge.bridgeJSLiftParameter(_self)
    let ret = _self.observedAttributes
    ret.bridgeJSStackPush()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_CustomElementBridge_observedAttributes_set")
@_cdecl("bjs_CustomElementBridge_observedAttributes_set")
public func _bjs_CustomElementBridge_observedAttributes_set(_ _self: UnsafeMutableRawPointer) -> Void {
    #if arch(wasm32)
    let value = [String].bridgeJSStackPop()
    let _self = CustomElementBridge.bridgeJSLiftParameter(_self)
    _self.observedAttributes = value
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_CustomElementBridge_deinit")
@_cdecl("bjs_CustomElementBridge_deinit")
public func _bjs_CustomElementBridge_deinit(_ pointer: UnsafeMutableRawPointer) -> Void {
    #if arch(wasm32)
    Unmanaged<CustomElementBridge>.fromOpaque(pointer).release()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

extension CustomElementBridge: ConvertibleToJSValue, _BridgedSwiftHeapObject, _BridgedSwiftProtocolExportable {
    var jsValue: JSValue {
        return .object(JSObject(id: UInt32(bitPattern: _bjs_CustomElementBridge_wrap(Unmanaged.passRetained(self).toOpaque()))))
    }
    consuming func bridgeJSLowerAsProtocolReturn() -> Int32 {
        _bjs_CustomElementBridge_wrap(Unmanaged.passRetained(self).toOpaque())
    }
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_CustomElementBridge_wrap")
fileprivate func _bjs_CustomElementBridge_wrap_extern(_ pointer: UnsafeMutableRawPointer) -> Int32
#else
fileprivate func _bjs_CustomElementBridge_wrap_extern(_ pointer: UnsafeMutableRawPointer) -> Int32 {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func _bjs_CustomElementBridge_wrap(_ pointer: UnsafeMutableRawPointer) -> Int32 {
    return _bjs_CustomElementBridge_wrap_extern(pointer)
}

extension JSShadowRootInit: BridgedSwiftGenericBridgeable {
    @_spi(BridgeJS) public static let bridgeJSTypeHandle = JSShadowRootInit.bridgeJSMakeTypeHandle()
}

extension CustomElementBridge: BridgedSwiftGenericBridgeable {
    @_spi(BridgeJS) public static let bridgeJSTypeHandle = CustomElementBridge.bridgeJSMakeTypeHandle()
}

#if arch(wasm32)
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_defineCustomElement")
fileprivate func bjs_defineCustomElement_extern(_ nameWord0: Int32, _ nameWord1: Int32, _ nameWord2: Int32, _ implementation: UnsafeMutableRawPointer) -> Void
#else
fileprivate func bjs_defineCustomElement_extern(_ nameWord0: Int32, _ nameWord1: Int32, _ nameWord2: Int32, _ implementation: UnsafeMutableRawPointer) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_defineCustomElement(_ nameWord0: Int32, _ nameWord1: Int32, _ nameWord2: Int32, _ implementation: UnsafeMutableRawPointer) -> Void {
    return bjs_defineCustomElement_extern(nameWord0, nameWord1, nameWord2, implementation)
}

func _$defineCustomElement(_ name: String, _ implementation: CustomElementBridge) throws(JSException) -> Void {
    name.bridgeJSWithLoweredParameter { (nameWord0, nameWord1, nameWord2) in
        let implementationPointer = implementation.bridgeJSLowerParameter()
        bjs_defineCustomElement(nameWord0, nameWord1, nameWord2, implementationPointer)
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
@_extern(wasm, module: "ElementaryWebComponents", name: "bjs_JSHTMLElement_getAttribute")
fileprivate func bjs_JSHTMLElement_getAttribute_extern(_ self: Int32, _ nameWord0: Int32, _ nameWord1: Int32, _ nameWord2: Int32) -> Void
#else
fileprivate func bjs_JSHTMLElement_getAttribute_extern(_ self: Int32, _ nameWord0: Int32, _ nameWord1: Int32, _ nameWord2: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSHTMLElement_getAttribute(_ self: Int32, _ nameWord0: Int32, _ nameWord1: Int32, _ nameWord2: Int32) -> Void {
    return bjs_JSHTMLElement_getAttribute_extern(self, nameWord0, nameWord1, nameWord2)
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

func _$JSHTMLElement_getAttribute(_ self: JSObject, _ name: String) throws(JSException) -> Optional<String> {
    name.bridgeJSWithLoweredParameter { (nameWord0, nameWord1, nameWord2) in
        let selfValue = self.bridgeJSLowerParameter()
        bjs_JSHTMLElement_getAttribute(selfValue, nameWord0, nameWord1, nameWord2)
    }
    if let error = _swift_js_take_exception() {
        throw error
    }
    return Optional<String>.bridgeJSLiftReturnFromSideChannel()
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
fileprivate func bjs_JSCSSStyleSheet_replaceSync_extern(_ self: Int32, _ cssWord0: Int32, _ cssWord1: Int32, _ cssWord2: Int32) -> Void
#else
fileprivate func bjs_JSCSSStyleSheet_replaceSync_extern(_ self: Int32, _ cssWord0: Int32, _ cssWord1: Int32, _ cssWord2: Int32) -> Void {
    fatalError("Only available on WebAssembly")
}
#endif
@inline(never) fileprivate func bjs_JSCSSStyleSheet_replaceSync(_ self: Int32, _ cssWord0: Int32, _ cssWord1: Int32, _ cssWord2: Int32) -> Void {
    return bjs_JSCSSStyleSheet_replaceSync_extern(self, cssWord0, cssWord1, cssWord2)
}

func _$JSCSSStyleSheet_init() throws(JSException) -> JSObject {
    let ret = bjs_JSCSSStyleSheet_init()
    if let error = _swift_js_take_exception() {
        throw error
    }
    return JSObject.bridgeJSLiftReturn(ret)
}

func _$JSCSSStyleSheet_replaceSync(_ self: JSObject, _ css: String) throws(JSException) -> Void {
    css.bridgeJSWithLoweredParameter { (cssWord0, cssWord1, cssWord2) in
        let selfValue = self.bridgeJSLowerParameter()
        bjs_JSCSSStyleSheet_replaceSync(selfValue, cssWord0, cssWord1, cssWord2)
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
        CustomElementBridge.bridgeJSTypeID,
    ]
    typeIds.withUnsafeBufferPointer { buffer in
        _bjs_ElementaryWebComponents_register_type_handles_extern(buffer.baseAddress, Int32(buffer.count))
    }
}
#endif