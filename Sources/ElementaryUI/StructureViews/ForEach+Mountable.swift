/// A structure that builds content for each element of a collection, identified by a stable id.
///
/// Each element's content is built and tracked separately: when reactive state read while building
/// one element changes, only that element's content is rebuilt.
///
/// ```swift
/// ForEach(todos, id: { $0.id }) { todo in
///     li { todo.title }
/// }
/// ```
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content> {
    // `ID` isn't stored: it is part of the type so that key-path ids can be added without breaking it.
    @usableFromInline let data: Data
    @usableFromInline let keys: [_ViewKey]
    @usableFromInline let content: (Data.Element) -> Content

    @usableFromInline
    init(data: Data, keys: [_ViewKey], content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.keys = keys
        self.content = content
    }

    /// Creates content for each element of `data`, identified by the given id.
    ///
    /// - Parameters:
    ///   - data: The collection of elements to build content for.
    ///   - id: Returns a stable identifier for an element.
    ///   - content: Builds the content for an element.
    @inlinable
    public init(
        _ data: Data,
        id: (Data.Element) -> ID,
        @ContentBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data: data, keys: data.map { _ViewKey(id($0)) }, content: content)
    }
}

public extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    /// Creates content for each element of a collection of identifiable elements.
    @inlinable
    init(
        _ data: Data,
        @ContentBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data, id: { $0.id }, content: content)
    }
}

public extension ForEach where Data == Range<Int>, ID == Int {
    /// Creates content for each integer in a range, using the integer as its id.
    @inlinable
    init(
        _ data: Range<Int>,
        @ContentBuilder content: @escaping (Int) -> Content
    ) {
        self.init(data, id: { $0 }, content: content)
    }
}

public extension ForEach where ID == _ViewKey {
    @available(*, deprecated, renamed: "init(_:id:content:)")
    @inlinable
    init<Key: LosslessStringConvertible>(
        _ data: Data,
        key: (Data.Element) -> Key,
        @ContentBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data: data, keys: data.map { _ViewKey(_UTF8Key(key($0))) }, content: content)
    }
}

extension ForEach: MarkupContent where Content: MarkupContent {
    public typealias Body = Never
}

extension ForEach: HTML where Content: HTML {}
extension ForEach: SVGContent where Content: SVGContent {}
extension ForEach: View where Content: View {}
extension ForEach: SVGView where Content: SVGView {}

extension ForEach: _Mountable where Content: MarkupContent & _Mountable {
    public typealias _MountedNode = _ForEachNode<Data, Content>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(view, context: context, ctx: &ctx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.patch(view, tx: &tx)
    }
}

#if !hasFeature(Embedded)
extension ForEach: _Renderable where Content: _Renderable {
    public static func _render<Renderer: _HTMLRendering>(
        _ html: consuming Self,
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) {
        for element in html.data {
            Content._render(html.content(element), into: &renderer, with: copy context)
        }
    }

    public static func _render<Renderer: _AsyncHTMLRendering>(
        _ html: consuming Self,
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) async throws {
        for element in html.data {
            try await Content._render(html.content(element), into: &renderer, with: copy context)
        }
    }
}
#endif
