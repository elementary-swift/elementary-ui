// Intentionally a base class: protocol witness tables keep the FLIP implementation
// reachable in minimal Wasm builds, while subclass overrides strip when FLIP is unused.
class DOMLayoutObserver: Unmountable {
    func willLayoutChildren(parent: DOM.Node, context: inout _TransactionContext) {}
    func setLeaveStatus(_ node: DOM.Node, isLeaving: Bool, context: inout _TransactionContext) {}
    func didLayoutChildren(
        parent: DOM.Node,
        entries: borrowing Span<LayoutPass.Entry>,
        context: inout _CommitContext
    ) {}
    func unmount(_ context: inout _CommitContext) {}
}

struct DOMLayoutObservers {
    private var storage: [DOMLayoutObserver] = []

    var isEmpty: Bool {
        storage.isEmpty
    }

    mutating func add(_ observer: DOMLayoutObserver) {
        storage.append(observer)
    }

    mutating func take() -> [DOMLayoutObserver] {
        let observers = storage
        storage.removeAll(keepingCapacity: true)
        return observers
    }
}
