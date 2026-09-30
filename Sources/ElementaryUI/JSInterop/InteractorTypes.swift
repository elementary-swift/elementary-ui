#if os(WASI)
import BrowserInterop
import JavaScriptKit

typealias DOMInteractor = BridgeJSDOMInteractor

extension DOM {
    @_spi(Benchmarking)
    public struct Node: Hashable {
        let ref: JSObject

        init(ref: JSObject) {
            self.ref = ref
        }

        public func hash(into hasher: inout Hasher) {
            ref.hash(into: &hasher)
        }

        public static func == (lhs: Node, rhs: Node) -> Bool {
            lhs.ref == rhs.ref
        }
    }

    @_spi(Benchmarking)
    public struct Event {
        let ref: JSObject

        init(ref: JSObject) {
            self.ref = ref
        }
    }

    @_spi(Benchmarking)
    public struct EventSink: ~Copyable {
        let ref: JSEventCallback

        init(ref: JSEventCallback) {
            self.ref = ref
        }

        deinit {
            ref.release()
        }
    }
}

extension _TypedDOMEvent {
    init?(raw: DOM.Event) {
        self.init(__jsObject: raw.ref)
    }
}
#else
extension DOM {
    @_spi(Benchmarking)
    public protocol Interactor: AnyObject {
        func makeEventSink(_ handler: @escaping () -> Void) -> EventSink
        func makeEventSink(_ handler: @escaping (Event) -> Void) -> EventSink

        func makePropertyAccessor(_ node: Node, name: String) -> PropertyAccessor
        func makeStyleAccessor(_ node: Node, cssName: String) -> StyleAccessor
        func makeComputedStyleAccessor(_ node: Node) -> ComputedStyleAccessor
        func makeFocusAccessor(_ node: Node, onEvent: @escaping (FocusEvent) -> Void) -> FocusAccessor

        func setStyleProperty(_ node: Node, name: String, value: String)
        func removeStyleProperty(_ node: Node, name: String)

        func createText(_ text: String) -> Node
        func createElement(_ element: String) -> Node
        func createElementNS(namespaceURI: String, element: String) -> Node

        func setAttribute(_ node: Node, name: String, value: String?)
        func removeAttribute(_ node: Node, name: String)

        func addEventListener(_ node: Node, event: String, sink: borrowing EventSink)
        func removeEventListener(_ node: Node, event: String, sink: borrowing EventSink)
        func patchText(_ node: Node, with text: String)
        func insertChild(_ child: Node, before sibling: Node?, in parent: Node)
        func appendChild(_ child: Node, to parent: Node)
        func removeChild(_ child: Node, from parent: Node)
        func clearChildren(in parent: Node)

        func querySelector(_ selector: String) -> Node?

        func queueMicrotask(_ callback: @escaping () -> Void)
        func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double)
        func requestAnimationFrame(_ callback: @escaping (Double) -> Void)
        func getCurrentTime() -> Double

        func animateElement(
            _ element: Node,
            _ effect: Animation.KeyframeEffect,
            onFinish: @escaping () -> Void
        ) -> Animation

        func getBoundingClientRect(_ node: Node) -> Rect
        func getOffsetParent(_ node: Node) -> Node?
        func getScrollOffset() -> (x: Double, y: Double)
    }

    @_spi(Benchmarking)
    public struct Node: Hashable {
        public let ref: AnyObject

        public init(ref: AnyObject) {
            self.ref = ref
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(ref))
        }

        public static func == (lhs: Node, rhs: Node) -> Bool {
            lhs.ref === rhs.ref
        }
    }

    @_spi(Benchmarking)
    public struct Event {
        let ref: AnyObject

        init(ref: AnyObject) {
            self.ref = ref
        }
    }

    @_spi(Benchmarking)
    public struct EventSink: ~Copyable {
        let ref: AnyObject

        public init(ref: AnyObject) {
            self.ref = ref
        }
    }
}

typealias DOMInteractor = any DOM.Interactor

var defaultDOMInteractor: DOMInteractor {
    fatalError("ElementaryUI apps can only be mounted in a WASI build")
}

extension _TypedDOMEvent {
    init?(raw: DOM.Event) {
        nil
    }
}

extension Application {
    @_spi(Benchmarking)
    public func _mount<Interactor: DOM.Interactor>(
        dom: Interactor,
        root: DOM.Node
    ) -> MountedApplication {
        let runtime = ApplicationRuntime(dom: dom, domRoot: root, appView: contentView)
        return MountedApplication(unmount: runtime.unmount)
    }
}
#endif

#if os(WASI)
@inline(never)
#endif
func addHTMLAttributes(_ attributes: _AttributeStorage, to node: DOM.Node, using dom: DOMInteractor) {
    DOMAttributePatcher(dom: dom).addHTMLAttributes(node, attributes)
}

#if os(WASI)
@inline(never)
#endif
func applyHTMLAttributes(
    from previousAttributes: _AttributeStorage,
    to newAttributes: _AttributeStorage,
    on node: DOM.Node,
    using dom: DOMInteractor
) {
    DOMAttributePatcher(dom: dom).applyHTMLAttributes(node, from: previousAttributes, to: newAttributes)
}
