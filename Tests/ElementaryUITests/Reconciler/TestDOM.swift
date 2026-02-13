@testable import ElementaryUI

private extension DOM.Event {
    //init(_ event: TestDOM) { self.init(ref: event) }
}

private extension DOM.EventSink {
    init(_ sink: TestDOM.EventSink) { self.init(ref: sink) }
    var value: TestDOM.EventSink { ref as! TestDOM.EventSink }
}

private extension DOM.Node {
    init(_ node: TestDOM.NodeRef) { self.init(ref: node) }
    var value: TestDOM.NodeRef { ref as! TestDOM.NodeRef }
}

final class TestDOM: DOM.Interactor {
    enum Op: Equatable, CustomStringConvertible {
        case createElement(String)
        case createText(String)
        case setAttr(node: String, name: String, value: String?)
        case removeAttr(node: String, name: String)
        case addListener(node: String, event: String)
        case removeListener(node: String, event: String)
        case patchText(node: String, to: String)
        case setChildren(parent: String, children: [String])
        case addChild(parent: String, child: String, before: String? = nil)
        case removeChild(parent: String, child: String)

        var description: String {
            switch self {
            case let .createElement(tag):
                "create <\(tag)>"
            case let .createText(text):
                "create '\(text)'"
            case let .setAttr(node, name, value):
                "setAttr \(node) \(name)=\(value ?? "nil")"
            case let .removeAttr(node, name):
                "removeAttr \(node) \(name)"
            case let .addListener(node, event):
                "addListener \(node) \(event)"
            case let .removeListener(node, event):
                "removeListener \(node) \(event)"
            case let .patchText(node, to):
                "patchText \(node) -> \(to)"
            case let .setChildren(parent, children):
                "setChildren \(parent) = [\(children.joined(separator: ", "))]"
            case let .addChild(parent, child, before):
                if let before {
                    "addChild \(parent) + \(child) before \(before)"
                } else {
                    "addChild \(parent) + \(child)"
                }
            case let .removeChild(parent, child):
                "removeChild \(parent) - \(child)"
            }
        }
    }
    // Element-only storage separated from node, to keep text nodes lean
    final class ElementData {
        let tag: String
        var children: [NodeRef] = []
        var attributes: [String: String?] = [:]
        var inlineStyles: [String: String] = [:]
        var listeners: Set<String> = []
        var sink: EventSink?

        init(tag: String) {
            self.tag = tag
        }
    }

    final class NodeRef {
        enum Kind {
            case element(ElementData)
            case text(String)
        }

        var kind: Kind
        weak var parent: NodeRef?

        init(kind: Kind) {
            self.kind = kind
        }

        var tagName: String? {
            if case let .element(data) = kind { return data.tag }
            return nil
        }

        var isElement: Bool {
            switch kind {
            case .element: true;
            case .text: false
            }
        }

        var textValue: String? {
            if case let .text(text) = kind { return text }
            return nil
        }

        // Convenience read-only access for tests
        var children: [NodeRef] {
            switch kind {
            case let .element(data):
                return data.children
            case .text:
                return []
            }
        }
    }

    final class EventSink {
        let handler: (String, DOM.Event) -> Void
        init(_ handler: @escaping (String, DOM.Event) -> Void) { self.handler = handler }
    }

    let root: DOM.Node
    private(set) var ops: [Op] = []
    private(set) var rafCallbacks: [(Double) -> Void] = []
    private(set) var timeoutCallbacks: [(() -> Void, Double)] = []
    private(set) var queueMicrotaskCallbacks: [() -> Void] = []

    var hasWorkScheduled: Bool { !rafCallbacks.isEmpty }

    init() {
        self.root = DOM.Node(NodeRef(kind: .element(ElementData(tag: ""))))
    }

    func querySelector(_ selector: String) -> DOM.Node? {
        fatalError("Not implemented")
    }

    func makeEventSink(_ handler: @escaping (String, DOM.Event) -> Void) -> DOM.EventSink {
        .init(EventSink(handler))
    }

    func makePropertyAccessor(_ node: DOM.Node, name: String) -> DOM.PropertyAccessor {
        fatalError("Not implemented")
    }

    func makeStyleAccessor(_ node: DOM.Node, cssName: String) -> DOM.StyleAccessor {
        fatalError("Not implemented")
    }

    func makeComputedStyleAccessor(_ node: DOM.Node) -> DOM.ComputedStyleAccessor {
        fatalError("Not implemented")
    }

    func makeFocusAccessor(_ node: DOM.Node, onEvent: @escaping (DOM.FocusEvent) -> Void) -> DOM.FocusAccessor {
        fatalError("Not implemented")
    }

    func setStyleProperty(_ node: DOM.Node, name: String, value: String) {
        guard case let .element(data) = node.value.kind else { return }
        data.inlineStyles[name] = value
        // Model as attribute op for trace? We keep ops minimal; no op appended here.
    }

    func removeStyleProperty(_ node: DOM.Node, name: String) {
        guard case let .element(data) = node.value.kind else { return }
        data.inlineStyles.removeValue(forKey: name)
        // No op trace for simplicity
    }

    func createText(_ text: String) -> DOM.Node {
        ops.append(.createText(text))
        return DOM.Node(NodeRef(kind: .text(text)))
    }

    func createElement(_ element: String) -> DOM.Node {
        ops.append(.createElement(element))
        return DOM.Node(NodeRef(kind: .element(ElementData(tag: element))))
    }

    func setAttribute(_ node: DOM.Node, name: String, value: String?) {
        guard case let .element(data) = node.value.kind else { return }
        data.attributes[name] = value
        ops.append(.setAttr(node: label(node), name: name, value: value))
    }

    func removeAttribute(_ node: DOM.Node, name: String) {
        guard case let .element(data) = node.value.kind else { return }
        data.attributes.removeValue(forKey: name)
        ops.append(.removeAttr(node: label(node), name: name))
    }

    func animateElement(_ node: DOM.Node, _ effect: DOM.Animation.KeyframeEffect, onFinish: @escaping () -> Void) -> DOM.Animation {
        .init(
            _cancel: {
                // TODO: implement
                print("TESTDOM: cancel animation")
            },
            _update: { effect in
                // TODO: implement
                print("TESTDOM: update animation \(effect)")
            }
        )
    }

    /// Mock bounding rect storage for FLIP tests - can be set per node
    var mockBoundingRects: [ObjectIdentifier: DOM.Rect] = [:]

    func getBoundingClientRect(_ node: DOM.Node) -> DOM.Rect {
        let id = ObjectIdentifier(node.value)
        return mockBoundingRects[id] ?? DOM.Rect(x: 0, y: 0, width: 0, height: 0)
    }

    /// Helper to set mock bounding rect for a node (for testing)
    func setMockBoundingRect(_ node: DOM.Node, rect: DOM.Rect) {
        mockBoundingRects[ObjectIdentifier(node.value)] = rect
    }

    func addEventListener(_ node: DOM.Node, event: String, sink: DOM.EventSink) {
        guard case let .element(data) = node.value.kind else { return }
        data.listeners.insert(event)
        data.sink = sink.value
        ops.append(.addListener(node: label(node), event: event))
    }

    func removeEventListener(_ node: DOM.Node, event: String, sink: DOM.EventSink) {
        guard case let .element(data) = node.value.kind else { return }
        data.listeners.remove(event)
        ops.append(.removeListener(node: label(node), event: event))
    }

    func patchText(_ node: DOM.Node, with text: String) {
        ops.append(.patchText(node: label(node), to: text))
        node.value.kind = .text(text)
    }

    func replaceChildren(_ children: [DOM.Node], in parent: DOM.Node) {
        guard case let .element(data) = parent.value.kind else { return }
        for child in children { child.value.parent = parent.value }
        data.children = children.map { $0.value }
        ops.append(.setChildren(parent: label(parent), children: children.map(label)))
    }

    func insertChild(_ child: DOM.Node, before sibling: DOM.Node?, in parent: DOM.Node) {
        let index: Int
        if let sibling, let i = parent.value.children.firstIndex(where: { $0 === sibling.value }) {
            index = i
        } else {
            index = parent.value.children.endIndex
        }
        child.value.parent = parent.value
        if case let .element(data) = parent.value.kind {
            data.children.insert(child.value, at: index)
        }
        ops.append(.addChild(parent: label(parent), child: label(child), before: sibling.map(label)))
    }

    func removeChild(_ child: DOM.Node, from parent: DOM.Node) {
        if case let .element(data) = parent.value.kind, let index = data.children.firstIndex(where: { $0 === child.value }) {
            data.children.remove(at: index)
            ops.append(.removeChild(parent: label(parent), child: label(child)))
        }
    }

    func getOffsetParent(_ node: DOM.Node) -> DOM.Node? {
        nil
    }

    func requestAnimationFrame(_ callback: @escaping (Double) -> Void) {
        rafCallbacks.append(callback)
    }

    func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double) {
        timeoutCallbacks.append((callback, timeout))
    }

    func queueMicrotask(_ callback: @escaping () -> Void) {
        queueMicrotaskCallbacks.append(callback)
    }

    func getCurrentTime() -> Double { 0 }

    func getScrollOffset() -> (x: Double, y: Double) {
        (x: 0, y: 0)
    }

    func flushMicrotasks() {
        while !queueMicrotaskCallbacks.isEmpty {
            queueMicrotaskCallbacks.removeFirst()()
        }
    }

    func runNextFrame() {
        runAllScheduledWork()
        guard let callback = rafCallbacks.first else { return }
        rafCallbacks.removeFirst()
        callback(0)
        runAllScheduledWork()
    }

    private func runAllScheduledWork() {
        flushMicrotasks()

        var ti = 0
        while ti < timeoutCallbacks.count {
            let (callback, timeout) = timeoutCallbacks[ti]
            if timeout == 0 {
                callback()
                timeoutCallbacks.remove(at: ti)
            } else {
                ti += 1
            }
        }
    }

    func clearOps() {
        ops = []
    }

    private func label(_ node: DOM.Node) -> String {
        switch node.value.kind {
        case let .element(data):
            return "<\(data.tag)>"
        case let .text(text):
            return "\(text)"
        }
    }
}

extension TestDOM.NodeRef.Kind {
    var tagName: String? {
        if case let .element(data) = self { return data.tag }
        return nil
    }
}

extension TestDOM.NodeRef.Kind: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)):
            return a == b
        case let (.element(la), .element(lb)):
            return la.tag == lb.tag
        default:
            return false
        }
    }
}

func mountOps(@HTMLBuilder _ view: @escaping () -> some View) -> [TestDOM.Op] {
    let dom = TestDOM()
    dom.mount(view)
    dom.runNextFrame()
    return dom.ops
}

func patchOps(@HTMLBuilder _ view: @escaping () -> some View, toggle: () -> Void) -> [TestDOM.Op] {
    let dom = TestDOM()
    dom.mount(view)
    dom.runNextFrame()
    dom.clearOps()
    print("---- PATCHING ----")
    toggle()
    dom.runNextFrame()
    return dom.ops
}

func trackMounting(@HTMLBuilder _ view: @escaping () -> some View) -> [String] {
    let dom = TestDOM()
    let tracker = RenderTracker()
    dom.mount { view().environment(#Key(\.tracker), tracker) }
    dom.flushMicrotasks()
    return tracker.calls
}

func trackUpdating(@HTMLBuilder _ view: @escaping () -> some View, toggle: () -> Void) -> [String] {
    let dom = TestDOM()
    let tracker = RenderTracker()
    dom.mount { view().environment(#Key(\.tracker), tracker) }
    dom.flushMicrotasks()
    tracker.reset()
    toggle()
    dom.runNextFrame()
    return tracker.calls
}

extension TestDOM {
    @discardableResult
    func mount(_ view: @escaping () -> some View) -> MountedApplication {
        let runtime = ApplicationRuntime(dom: self, domRoot: self.root, appView: DeferredResolutionView(root: view))
        return MountedApplication(unmount: runtime.unmount)
    }
}

@View
private struct DeferredResolutionView<RootView: View> {
    let root: () -> RootView

    var body: some View {
        root()
    }
}
