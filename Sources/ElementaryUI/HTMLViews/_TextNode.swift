public final class _TextNode: _Reconcilable {
    var value: String
    var domNode: ManagedDOMReference?
    var isDirty: Bool = false
    var parentElement: _ElementNode?

    init(_ newValue: String, viewContext: borrowing _ViewContext, context: inout _TransactionContext) {
        self.value = newValue
        self.domNode = nil
        self.parentElement = viewContext.parentElement

        self.parentElement?.reportChangedChildren(.elementAdded, tx: &context)

        isDirty = true
        context.scheduler.addCommitAction { [self] context in
            self.domNode = ManagedDOMReference(reference: context.dom.createText(newValue), status: .added)
            self.isDirty = false
        }
    }

    func patch(_ newValue: String, context: inout _TransactionContext) {
        let needsUpdate = !isDirty && !value.utf8Equals(newValue)
        self.value = newValue

        guard needsUpdate else { return }

        isDirty = true
        context.scheduler.addCommitAction { [self] context in
            assert(isDirty, "text node is not dirty")
            assert(domNode != nil, "text node is not mounted")

            (domNode?.reference).map { context.dom.patchText($0, with: value) }
            self.isDirty = false
        }
    }

    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        assert(domNode != nil, "unitialized text node in layout pass")
        domNode?.collectLayoutChanges(&ops, type: .text)
    }

    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        switch op {
        case .startRemoval:
            domNode?.status = .removed
            self.parentElement?.reportChangedChildren(.elementRemoved, tx: &tx)
        case .markAsMoved:
            domNode?.status = .moved
            self.parentElement?.reportChangedChildren(.elementMoved, tx: &tx)
        case .cancelRemoval:
            // a text node can not leave and re-enter
            break
        case .markAsLeaving:
            // no-op
            break
        }
    }

    public func unmount(_ context: inout _CommitContext) {
        self.domNode = nil
        self.parentElement = nil
    }
}
