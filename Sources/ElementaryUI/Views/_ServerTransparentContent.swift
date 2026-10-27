/// A view that renders only its content on the server, dropping its client-side behavior.
protocol _ServerTransparentContent: MarkupContent {
    associatedtype _ServerContent: MarkupContent
    var _serverContent: _ServerContent { get }
}

#if !hasFeature(Embedded)
extension _ServerTransparentContent {
    static func _render<Renderer: _HTMLRendering>(
        _ html: consuming Self,
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) {
        _ServerContent._render(html._serverContent, into: &renderer, with: context)
    }

    static func _render<Renderer: _AsyncHTMLRendering>(
        _ html: consuming Self,
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) async throws {
        try await _ServerContent._render(html._serverContent, into: &renderer, with: context)
    }
}
#endif
