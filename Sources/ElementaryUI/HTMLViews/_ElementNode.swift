public struct _ElementNode:
    ~Copyable,
    _Reconcilable
{
    private var child: AnyReconcilable
    private var attributes: _ElementAttributes
    private var mountedModifiers: [AnyUnmountable] = []

    @inline(never)
    init(
        tag: String,
        namespaceURI: String? = nil,
        attributes: _AttributeStorage,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeChild: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) {
        let domNode: DOM.Node
        if let namespaceURI {
            domNode = ctx.dom.createElementNS(
                namespaceURI: namespaceURI,
                element: tag
            )
        } else {
            domNode = ctx.dom.createElement(tag)
        }

        ctx.appendStaticElement(domNode)

        guard !context.hasNoUpstreamModifiers else {
            self.attributes = .mountInline(
                attributes,
                on: domNode,
                using: ctx.dom
            )
            self.child = ctx.withChildContext {
                (mctx: consuming _MountContext) in
                let child = makeChild(context, &mctx)
                _ = mctx.mountInDOMNode(domNode, observers: [])
                return child
            }
            return
        }

        var childContext = copy context
        if childContext.modifiers[_AttributeModifier.key] != nil {
            let modifier = _AttributeModifier(
                value: attributes,
                upstream: childContext.modifiers
            )
            self.attributes = .mountModifier(modifier)
            childContext.modifiers[_AttributeModifier.key] = modifier
        } else {
            self.attributes = .mountInline(
                attributes,
                on: domNode,
                using: ctx.dom
            )
        }

        let modifiers = childContext.takeModifiers()
        let layoutObservers = childContext.takeLayoutObservers()

        self.mountedModifiers.reserveCapacity(modifiers.count)
        for modifier in modifiers.reversed() {
            self.mountedModifiers.append(modifier.mount(domNode, &ctx))
        }

        self.child = ctx.withChildContext {
            (mctx: consuming _MountContext) in
            let child = makeChild(childContext, &mctx)
            _ = mctx.mountInDOMNode(
                domNode,
                observers: layoutObservers
            )
            return child
        }
    }

    @inline(never)
    mutating func update(
        attributes: _AttributeStorage,
        _ context: inout _TransactionContext,
        block: (inout AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        self.attributes.patch(attributes, context: &context)
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

struct _ElementAttributes {
    private enum Storage {
        case inline(node: DOM.Node, lastApplied: _AttributeStorage)
        case modifier(_AttributeModifier)
    }

    private var storage: Storage

    private init(storage: consuming Storage) {
        self.storage = storage
    }

    static func mountInline(
        _ attributes: _AttributeStorage,
        on node: DOM.Node,
        using dom: DOMInteractor
    ) -> Self {
        addHTMLAttributes(attributes, to: node, using: dom)
        return Self(
            storage: .inline(node: node, lastApplied: attributes)
        )
    }

    static func mountModifier(
        _ modifier: consuming _AttributeModifier
    ) -> Self {
        Self(storage: .modifier(modifier))
    }

    @inline(never)
    mutating func patch(
        _ attributes: _AttributeStorage,
        context: inout _TransactionContext
    ) {
        switch storage {
        case .modifier(let modifier):
            modifier.updateValue(attributes, &context)
        case .inline(let node, let lastApplied):
            guard attributes != lastApplied else { return }
            context.scheduler.addCommitAction(
                .patchAttributes(
                    node: node,
                    from: lastApplied,
                    to: attributes
                )
            )
            storage = .inline(
                node: node,
                lastApplied: attributes
            )
        }
    }
}
