import JavaScriptKit

// NOTE: all of this is because tasks were not a thing in embedded until recently
// revisit in 6.3

public protocol EventSource<Event> {
    associatedtype Event
    func subscribe(_ callback: @escaping (Event) -> Void) -> EventSourceSubscription
}

public struct EventSourceSubscription {
    let _cancel: () -> Void

    public func cancel() {
        _cancel()
    }
}

public extension View {
    func receive<Event>(_ eventSource: some EventSource<Event>, handler: @escaping (Event) -> Void) -> some View<Tag> {
        _LifecycleEventView(
            wrapped: self,
            listener: .onAppearReturningCancelFunction {
                let subscription = eventSource.subscribe(handler)
                return subscription.cancel
            }
        )
    }
}

public enum GlobalDocument {
    static let document = JSObject.global.document

    static var body: DOM.Node {
        DOM.Node(document.body.object!)
    }
}

extension GlobalDocument {
    public static var onKeyDown: some EventSource<KeyboardEvent> {
        DOMEventSource(eventName: "keydown")
    }

    struct DOMEventSource<Event: _TypedDOMEvent>: EventSource {
        typealias Event = Event

        let eventName: String

        func subscribe(_ callback: @escaping (Event) -> Void) -> EventSourceSubscription {
            let closure = JSClosure { event in
                callback(Event(__jsObject: event[0].object!)!)
                return .undefined
            }

            _ = document.addEventListener(eventName, closure)

            return EventSourceSubscription {
                _ = document.removeEventListener(eventName, closure)
            }
        }
    }
}

//TODO: should be have some scope for this?
public var onAnimationFrame: some EventSource<AnimationFrameEvent> {
    AnimationFrameEventSource()
}

struct AnimationFrameEventSource: EventSource {
    typealias Event = AnimationFrameEvent
    static let _requestAnimationFrame = JSObject.global.requestAnimationFrame.function!
    static let _cancelAnimationFrame = JSObject.global.cancelAnimationFrame.function!

    func subscribe(_ callback: @escaping (AnimationFrameEvent) -> Void) -> EventSourceSubscription {
        var rafID: JSValue?
        var closure: JSClosure?

        closure = JSClosure { value in
            guard let closure else {
                return .undefined
            }
            rafID = AnimationFrameEventSource._requestAnimationFrame(closure)
            callback(AnimationFrameEvent(timestamp: value[0].number!))
            return .undefined
        }

        rafID = AnimationFrameEventSource._requestAnimationFrame(closure)

        return EventSourceSubscription {
            if let rafID = rafID {
                AnimationFrameEventSource._cancelAnimationFrame(rafID)
            }
            closure = nil
            rafID = nil
        }
    }
}

public struct AnimationFrameEvent {
    public let timestamp: Double
}
