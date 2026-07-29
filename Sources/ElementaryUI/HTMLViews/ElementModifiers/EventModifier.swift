public protocol _DOMEventConfig {
    static var name: String { get }
}

public protocol _DOMEventHandlerConfig: _DOMEventConfig {
    associatedtype Event: _TypedDOMEvent
}

final class EventHandlerModifier<Config: _DOMEventHandlerConfig>: DOMElementModifier {
    typealias Value = (Config.Event) -> Void

    let upstream: EventHandlerModifier?

    private var value: Value

    init(value: consuming @escaping Value, upstream: borrowing DOMElementModifiers) {
        self.value = value
        self.upstream = upstream[EventHandlerModifier.key]
    }

    func updateValue(_ value: consuming @escaping Value, _ context: inout _TransactionContext) {
        self.value = value
    }

    func mount(_ node: DOM.Node, _ context: inout _MountContext) -> AnyUnmountable {
        logTrace("mounting event modifier")
        return AnyUnmountable(MountedInstance(node, self, &context))
    }

    func handleEvent(_ event: DOM.Event) {
        guard let event = Config.Event(raw: event) else {
            logWarning("Unexpected event type for \(Config.name)")
            return
        }

        value(event)
        upstream?.value(event)
    }
}

extension EventHandlerModifier {
    final class MountedInstance: Unmountable {
        var sink: DOM.EventSink?

        init(_ node: DOM.Node, _ modifier: EventHandlerModifier, _ context: inout _MountContext) {
            let sink = context.dom.makeEventSink { [modifier] event in
                modifier.handleEvent(event)
            }

            context.dom.addEventListener(node, event: Config.name, sink: sink)
            self.sink = consume sink
        }

        func unmount(_ context: inout _CommitContext) {
            _ = self.sink.take()
        }
    }
}

// Keep no-argument handlers separate from EventHandlerModifier so they do not
// materialize DOM.Event or pull typed-event conversion code into the Wasm binary.
final class EventActionModifier<Config: _DOMEventConfig>: DOMElementModifier {
    typealias Value = () -> Void

    let upstream: EventActionModifier?
    private var value: Value

    init(value: consuming @escaping Value, upstream: borrowing DOMElementModifiers) {
        self.value = value
        self.upstream = upstream[EventActionModifier.key]
    }

    func updateValue(_ value: consuming @escaping Value, _ context: inout _TransactionContext) {
        self.value = value
    }

    func mount(_ node: DOM.Node, _ context: inout _MountContext) -> AnyUnmountable {
        logTrace("mounting event action modifier")
        return AnyUnmountable(MountedInstance(node, self, &context))
    }

    func handleEvent() {
        value()
        upstream?.value()
    }
}

extension EventActionModifier {
    final class MountedInstance: Unmountable {
        var sink: DOM.EventSink?

        init(_ node: DOM.Node, _ modifier: EventActionModifier, _ context: inout _MountContext) {
            let sink = context.dom.makeEventSink { [modifier] in
                modifier.handleEvent()
            }

            context.dom.addEventListener(node, event: Config.name, sink: sink)
            self.sink = consume sink
        }

        func unmount(_ context: inout _CommitContext) {
            _ = sink.take()
        }
    }
}
