import BrowserInterop
import JavaScriptKit

// NOTE: all of this is because
// a) Tasks are not yet supported for embedded wasm (so we can't use `.task` with an async sequence)
// b) Combine obvsiously won't fly
// ideally, once tasks work in embedded wasm, we can replace this with an AsyncSequence

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
    static var body: DOM.Node {
        guard let document = try? BrowserInterop.document,
              let body = try? document.body else {
            return DOM.Node(ref: JSObject())
        }
        return DOM.Node(ref: body.jsObject)
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

            guard let document = try? BrowserInterop.document else {
                return EventSourceSubscription {}
            }
            _ = try? document.addEventListener(eventName, closure)

            return EventSourceSubscription {
                _ = try? document.removeEventListener(eventName, closure)
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

    func subscribe(_ callback: @escaping (AnimationFrameEvent) -> Void) -> EventSourceSubscription {
        var rafID: Double?
        var closure: ((Double) -> Void)?

        closure = { value in
            guard let closure else {
                return
            }
            rafID = try? BrowserInterop.requestAnimationFrame(closure)
            callback(AnimationFrameEvent(timestamp: value))
        }

        if let closure {
            rafID = try? BrowserInterop.requestAnimationFrame(closure)
        }

        return EventSourceSubscription {
            if let rafID = rafID {
                _ = try? BrowserInterop.cancelAnimationFrame(rafID)
            }
            closure = nil
            rafID = nil
        }
    }
}

public struct AnimationFrameEvent {
    public let timestamp: Double
}
