public struct _TextNode: _Reconcilable {
    let domNode: DOM.Node
    var value: String

    init(_ newValue: String, ctx: inout _MountContext) {
        self.value = newValue
        self.domNode = ctx.dom.createText(newValue)
        ctx.appendStaticText(self.domNode)
    }

    mutating func patch(_ newValue: String, tx: inout _TransactionContext) {
        guard !value.utf8Equals(newValue) else { return }
        self.value = newValue

        tx.scheduler.addCommitAction { [self] ctx in
            ctx.dom.patchText(domNode, with: value)
        }
    }

    public consuming func unmount(_ context: inout _CommitContext) {
    }
}
