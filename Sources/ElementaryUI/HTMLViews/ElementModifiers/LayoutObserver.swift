protocol DOMLayoutObserver: Unmountable {
    func willLayoutChildren(parent: DOM.Node, context: inout _TransactionContext)
    func setLeaveStatus(_ node: DOM.Node, isLeaving: Bool, context: inout _TransactionContext)
    func didLayoutChildren(parent: DOM.Node, entries: borrowing Span<LayoutPass.Entry>, context: inout _CommitContext)
}

struct DOMLayoutObservers {
    private var storage: [any DOMLayoutObserver] = []

    var isEmpty: Bool {
        storage.isEmpty
    }

    mutating func add(_ observer: any DOMLayoutObserver) {
        storage.append(observer)
    }

    mutating func take() -> [any DOMLayoutObserver] {
        let observers = storage
        storage.removeAll(keepingCapacity: true)
        return observers
    }
}
