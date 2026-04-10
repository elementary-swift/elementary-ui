import _UTF8Internals

public protocol _DOMEventHandlerConfig {
    static var name: String { get }
    associatedtype Event: _TypedDOMEvent
}

final class EventModifier<Config: _DOMEventHandlerConfig>: DOMElementModifier {
    typealias Value = (Config.Event) -> Void

    let upstream: EventModifier?

    private var value: Value

    init(value: consuming @escaping Value, upstream: borrowing DOMElementModifiers) {
        self.value = value
        self.upstream = upstream[EventModifier.key]
    }

    func updateValue(_ value: consuming @escaping Value, _ context: inout _TransactionContext) {
        self.value = value
    }

    func mount(_ node: DOM.Node, _ context: inout _MountContext) -> AnyUnmountable {
        logTrace("mounting event modifier")
        return AnyUnmountable(MountedInstance(node, self, &context))
    }

    func handleEvent(_ name: String, event: DOM.Event) {
        assert(name.utf8Equals(Config.name), "Unexpected event name for \(Config.name)")
        guard let event = Config.Event(raw: event) else {
            logWarning("Unexpected event type for \(Config.name)")
            return
        }

        value(event)
        upstream?.value(event)
    }
}

extension EventModifier {
    final class MountedInstance: Unmountable {
        let modifier: EventModifier
        let node: DOM.Node
        var sink: DOM.EventSink?

        var isDirty: Bool = false

        init(_ node: DOM.Node, _ modifier: EventModifier, _ context: inout _MountContext) {
            self.node = node
            self.modifier = modifier

            let sink = context.dom.makeEventSink { [modifier] name, event in
                modifier.handleEvent(name, event: event)
            }

            context.dom.addEventListener(node, event: Config.name, sink: sink)
            self.sink = consume sink
        }

        func unmount(_ context: inout _CommitContext) {
            _ = self.sink.take()
        }
    }
}
