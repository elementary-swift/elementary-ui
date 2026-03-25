@_spi(BridgeJS) import JavaScriptKit

public typealias JSEventCallback = JSTypedClosure<(JSEvent) -> Void>

public extension JSEventCallback {
    // NOTE: this is a workaround because the codegen makes an internal initializer
    // https://github.com/swiftwasm/JavaScriptKit/issues/709
    static func make(fileID: StaticString = #fileID, line: UInt32 = #line, _ body: @escaping (JSEvent) -> Void) -> JSEventCallback {
        JSTypedClosure<(JSEvent) -> Void>(fileID: fileID, line: line, body)
    }
}

@JSClass(jsName: "Event")
public struct JSEvent {
    @JSGetter public var type: String
    @JSGetter public var target: JSObject
}

@JSClass(jsName: "KeyboardEvent")
public struct JSKeyboardEvent {
    @JSGetter public var key: String
}

@JSClass(jsName: "MouseEvent")
public struct JSMouseEvent {
    @JSGetter public var altKey: Bool
    @JSGetter public var button: Int
    @JSGetter public var buttons: Int
    @JSGetter public var clientX: Double
    @JSGetter public var clientY: Double
    @JSGetter public var ctrlKey: Bool
    @JSGetter public var metaKey: Bool
    @JSGetter public var movementX: Double
    @JSGetter public var movementY: Double
    @JSGetter public var offsetX: Double
    @JSGetter public var offsetY: Double
    @JSGetter public var pageX: Double
    @JSGetter public var pageY: Double
    @JSGetter public var screenX: Double
    @JSGetter public var screenY: Double
    @JSGetter public var shiftKey: Bool
}

@JSClass(jsName: "InputEvent")
public struct JSInputEvent {
    //FIXME: EMBEDDED - String? is not supported with BridgeJS
    // https://github.com/swiftwasm/JavaScriptKit/issues/689
    //@JSGetter public var data: String?
    @JSGetter public var data: String
    @JSGetter public var target: JSObject
}
