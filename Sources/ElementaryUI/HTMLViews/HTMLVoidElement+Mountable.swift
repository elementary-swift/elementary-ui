extension HTMLVoidElement: View, _Mountable, _DOMElementMounting {
    var element: _AnyDOMElement<EmptyHTML> {
        _AnyDOMElement(
            tag: Tag.name,
            attributes: _attributes,
            content: EmptyHTML()
        )
    }
}
