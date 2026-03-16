public struct _ElementNode<Child: _Reconcilable>: _Reconcilable {
    private var child: Child
    private var mountedModifiers: [AnyUnmountable]?

    init(
        tag: String,
        viewContext: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeChild: (borrowing _ViewContext, inout _MountContext) -> Child
    ) {
        let domNode = ctx.dom.createElement(tag)

        var childContext = copy viewContext
        let modifiers = childContext.takeModifiers()
        let layoutObservers = childContext.takeLayoutObservers()

        var mountedModifiers: [AnyUnmountable] = []
        for modifier in modifiers.reversed() {
            mountedModifiers.append(modifier.mount(domNode, &ctx))
        }
        self.mountedModifiers = mountedModifiers

        ctx.appendStaticElement(domNode)

        self.child = ctx.withChildContext { (mctx: consuming _MountContext) in
            let child = makeChild(childContext, &mctx)
            _ = mctx.mountInDOMNode(domNode, observers: layoutObservers)  //NOTE: maybe hold on to the container?
            return child
        }
    }

    mutating func updateChild(
        _ context: inout _TransactionContext,
        block: (inout Child, inout _TransactionContext) -> Void
    ) {
        block(&child, &context)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        child.unmount(&context)

        for modifier in mountedModifiers ?? [] {
            modifier.unmount(&context)
        }
        mountedModifiers = nil
    }
}
