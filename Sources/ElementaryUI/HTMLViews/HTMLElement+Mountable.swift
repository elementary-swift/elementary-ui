extension HTMLElement: View, _Mountable, _DOMElementMounting where Content: _Mountable {
    var element: _AnyDOMElement<Content> {
        _AnyDOMElement(
            tag: Tag.name,
            attributes: _attributes,
            content: content
        )
    }
}

protocol _DOMElementMounting {
    associatedtype Content: _Mountable

    var element: _AnyDOMElement<Content> { get }
}

extension _DOMElementMounting {
    public typealias _MountedNode = _TransitionableNode<_ElementNode<Content._MountedNode>>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _TransitionableNode(view.element, context: context, ctx: &ctx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.update(view.element, &tx)
    }
}

struct _AnyDOMElement<Content: _Mountable>: _Mountable {
    typealias _MountedNode = _ElementNode<Content._MountedNode>

    var namespaceURI: String?
    var tag: String
    var attributes: _AttributeStorage
    var content: Content

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _ElementNode(
            tag: view.tag,
            namespaceURI: view.namespaceURI,
            attributes: view.attributes,
            context: context,
            ctx: &ctx,
            makeChild: { viewContext, ctx in
                Content._makeNode(view.content, context: viewContext, ctx: &ctx)
            }
        )
    }

    static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.update(attributes: view.attributes, &tx) { element, tx in
            Content._patchNode(view.content, node: &element, tx: &tx)
        }
    }
}
