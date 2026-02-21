import BrowserInterop
import JavaScriptKit

// TODO: figure out the typing for this, this is not great
public protocol _TypedDOMEvent {
    init?(__jsObject: JSObject)
}

extension _TypedDOMEvent {
    init?(raw: DOM.Event) {
        guard let rawEvent = raw.ref as? JSObject else {
            return nil
        }

        self.init(__jsObject: rawEvent)
    }
}

public struct KeyboardEvent: _TypedDOMEvent {
    var rawEvent: JSObject

    public init?(__jsObject rawEvent: JSObject) {
        self.rawEvent = rawEvent
    }

    public var key: String {
        (try? JSKeyboardEvent(unsafelyWrapping: rawEvent).key) ?? ""
    }
}

public struct MouseEvent: _TypedDOMEvent {
    var rawEvent: JSObject

    public init?(__jsObject rawEvent: JSObject) {
        self.rawEvent = rawEvent
    }

    public var altKey: Bool {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).altKey) ?? false
    }

    public var button: Int {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).button) ?? 0
    }

    public var buttons: Int {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).buttons) ?? 0
    }

    public var clientX: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).clientX) ?? 0
    }

    public var clientY: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).clientY) ?? 0
    }

    public var ctrlKey: Bool {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).ctrlKey) ?? false
    }

    public var metaKey: Bool {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).metaKey) ?? false
    }

    public var movementX: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).movementX) ?? 0
    }

    public var movementY: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).movementY) ?? 0
    }

    public var offsetX: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).offsetX) ?? 0
    }

    public var offsetY: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).offsetY) ?? 0
    }

    public var pageX: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).pageX) ?? 0
    }

    public var pageY: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).pageY) ?? 0
    }

    public var screenX: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).screenX) ?? 0
    }

    public var screenY: Double {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).screenY) ?? 0
    }

    public var shiftKey: Bool {
        (try? JSMouseEvent(unsafelyWrapping: rawEvent).shiftKey) ?? false
    }
}

public struct InputEvent: _TypedDOMEvent {
    var rawEvent: JSObject

    public init?(__jsObject rawEvent: JSObject) {
        self.rawEvent = rawEvent
    }

    public var data: String? {
        try? JSInputEvent(unsafelyWrapping: rawEvent).data
    }

    public var targetValue: String? {
        (try? JSInputEvent(unsafelyWrapping: rawEvent).target.value.string) ?? nil
    }
}
