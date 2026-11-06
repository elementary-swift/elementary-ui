import BasicContainers
import ContainersPreview
import SpanPreview

/// A buffer that is reused for collecting elements in ``ScratchFrame``s.
struct ScratchBuffer<Element: ~Copyable>: ~Copyable {
    private var storage: UniqueArray<Element>

    init(minimumCapacity: Int) {
        storage = UniqueArray(minimumCapacity: minimumCapacity)
    }

    @_lifetime(&self)
    mutating func frame() -> ScratchFrame<Element> {
        ScratchFrame(&storage)
    }

    mutating func withFrame<R: ~Copyable>(_ body: (consuming ScratchFrame<Element>) -> R) -> R {
        body(frame())
    }
}

/// The elements appended since the frame opened, at the end of a shared,
/// reused buffer: collecting into a frame does not allocate once the buffer
/// has grown.
///
/// Frames nest: a nested frame borrows its parent. End every frame by
/// emptying it (`take`, `drain`, `passToParent`), and end a nested frame
/// by consuming its owner: a value with a deinit otherwise lives to the end of
/// its scope, past where the parent appends again.
struct ScratchFrame<Element: ~Copyable>: ~Copyable, ~Escapable {
    private var buffer: _MutableRef<UniqueArray<Element>>
    private var start: Int

    @_lifetime(&buffer)
    fileprivate init(_ buffer: inout UniqueArray<Element>) {
        self.start = buffer.count
        self.buffer = _MutableRef(&buffer)
    }

    var count: Int { buffer.value.count - start }
    var isEmpty: Bool { count == 0 }

    @inline(__always)
    mutating func append(_ element: consuming Element) {
        buffer.value.append(element)
    }

    /// A frame for the elements appended from now on.
    @_lifetime(&self)
    mutating func nested() -> ScratchFrame {
        ScratchFrame(&buffer.value)
    }

    mutating func popLast() -> Element? {
        isEmpty ? nil : buffer.value.removeLast()
    }

    /// Moves the elements out, into exactly sized storage that is not
    /// allocated when the frame is empty.
    mutating func take() -> RigidArray<Element> {
        var result = RigidArray<Element>(capacity: count)
        buffer.value.consumeLast(count) { span in
            result.append(moving: &span)
        }
        return result
    }

    /// Leaves the elements to the enclosing frame.
    mutating func passToParent() {
        start = buffer.value.count
    }

    /// Hands the elements to `body` and removes them; what `body` does not
    /// consume is dropped.
    mutating func drain(_ body: (inout InputSpan<Element>) -> Void) {
        buffer.value.consumeLast(count, consumingWith: body)
    }

    deinit {
        assert(isEmpty, "scratch frame ended with elements left")
    }
}
