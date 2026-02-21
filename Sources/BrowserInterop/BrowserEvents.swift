import JavaScriptKit

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
    @JSGetter public var data: String?
    @JSGetter public var target: JSObject
}
