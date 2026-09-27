extension SVGElement: SVGView, _Mountable, _DOMElementMounting where Content: _Mountable {
    var element: _AnyDOMElement<Content> {
        _AnyDOMElement(
            namespaceURI: SVGAttributeValue.xmlNamespace,
            tag: Tag.name,
            attributes: _attributes,
            content: content
        )
    }
}

extension SVGElement: View where Tag == SVGTag.svg, Content: _Mountable {}
