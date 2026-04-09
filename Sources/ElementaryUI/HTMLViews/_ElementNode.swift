enum _ElementAttributes {
    case inline(node: DOM.Node, lastApplied: _AttributeStorage)
    case modifier(_AttributeModifier)
}

public struct _ElementNode<Child: _Reconcilable & ~Copyable>: ~Copyable, _Reconcilable {
    private var child: Child
    private var attributes: _ElementAttributes
    private var mountedModifiers: [AnyUnmountable] = []

    init(
        tag: String,
        attributes: _AttributeStorage,
        viewContext: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeChild: (borrowing _ViewContext, inout _MountContext) -> Child
    ) {
        let domNode = ctx.dom.createElement(tag)

        ctx.appendStaticElement(domNode)

        guard !viewContext.hasNoUpstreamModifiers else {
            // no upstream: apply attributes directly, skip context copy and _AttributeModifier check
            ctx.dom.addHTMLAttributes(domNode, attributes)
            self.attributes = .inline(node: domNode, lastApplied: attributes)
            self.child = ctx.withChildContext { (mctx: consuming _MountContext) in
                let child = makeChild(viewContext, &mctx)
                _ = mctx.mountInDOMNode(domNode, observers: [])
                return child
            }
            return
        }

        var childContext = copy viewContext

        if childContext.modifiers[_AttributeModifier.key] != nil {
            // upstream modifier exists: chain through _AttributeModifier as before
            let modifier = _AttributeModifier(value: attributes, upstream: childContext.modifiers)
            self.attributes = .modifier(modifier)
            childContext.modifiers[_AttributeModifier.key] = modifier
        } else {
            // no upstream: apply attributes directly, skip _AttributeModifier allocation
            ctx.dom.addHTMLAttributes(domNode, attributes)
            self.attributes = .inline(node: domNode, lastApplied: attributes)
        }

        let modifiers = childContext.takeModifiers()
        let layoutObservers = childContext.takeLayoutObservers()

        self.mountedModifiers.reserveCapacity(modifiers.count)

        for modifier in modifiers.reversed() {
            self.mountedModifiers.append(modifier.mount(domNode, &ctx))
        }

        self.child = ctx.withChildContext { (mctx: consuming _MountContext) in
            let child = makeChild(childContext, &mctx)
            _ = mctx.mountInDOMNode(domNode, observers: layoutObservers)  //NOTE: maybe hold on to the container?
            return child
        }
    }

    mutating func update(
        attributes: _AttributeStorage,
        _ context: inout _TransactionContext,
        block: (inout Child, inout _TransactionContext) -> Void
    ) {
        switch self.attributes {
        case .modifier(let modifier):
            modifier.updateValue(attributes, &context)
        case .inline(let node, let lastApplied):
            if attributes != lastApplied {
                context.scheduler.addCommitAction(.patchAttributes(node: node, from: lastApplied, to: attributes))
                self.attributes = .inline(node: node, lastApplied: attributes)
            }
        }
        block(&child, &context)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        child.unmount(&context)

        for modifier in mountedModifiers {
            modifier.unmount(&context)
        }
        mountedModifiers.removeAll()
    }
}

private extension _ViewContext {
    var hasNoUpstreamModifiers: Bool {
        modifiers.isEmpty && layoutObservers.isEmpty
    }
}
