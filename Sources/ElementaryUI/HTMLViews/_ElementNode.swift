public struct _ElementNode:
    ~Copyable
{
    private var child: UniqueAny
    private var attributes: _ElementAttributes

    @inline(never)
    init(
        tag: String,
        namespaceURI: String? = nil,
        attributes: _AttributeStorage,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeChild: (borrowing _ViewContext, inout _MountContext) -> UniqueAny
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
            var childCtx = ctx.childContext()
            self.child = makeChild(context, &childCtx)
            childCtx.mountInDOMNode(domNode)
            return
        }

        var childContext = copy context
        if childContext.modifiers[AttributeModifier.key] != nil {
            let modifier = AttributeModifier(
                value: attributes,
                upstream: childContext.modifiers,
                ctx: &ctx
            )
            self.attributes = .mountModifier(modifier)
            childContext.modifiers[AttributeModifier.key] = modifier
        } else {
            self.attributes = .mountInline(
                attributes,
                on: domNode,
                using: ctx.dom
            )
        }

        let modifiers = childContext.takeModifiers()
        let layoutObservers = childContext.takeLayoutObservers()

        var childCtx = ctx.childContext()
        self.child = makeChild(childContext, &childCtx)
        childCtx.mountInDOMNode(domNode, observers: layoutObservers)

        // after the children, so the slot unmounts them first
        let modifierSpan = modifiers.span
        for index in modifierSpan.indices.reversed() {
            modifierSpan[index].mount(domNode, &ctx)
        }
    }

    @inline(never)
    mutating func update(
        attributes: _AttributeStorage,
        _ context: inout _TransactionContext,
        block: (inout UniqueAny, inout _TransactionContext) -> Void
    ) {
        self.attributes.patch(attributes, context: &context)
        block(&child, &context)
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
        case modifier(AttributeModifier)
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
        _ modifier: consuming AttributeModifier
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
