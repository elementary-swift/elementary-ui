import BasicContainers
import ContainersPreview

struct ScratchStack<Element: ~Copyable>: ~Copyable, ~Escapable {
    var storage: Inout<UniqueArray<Element>>
    private let startIndex: Int

    @_lifetime(&storage)
    init(storage: inout UniqueArray<Element>) {
        let startIndex = storage.count
        self.storage = Inout(&storage)
        self.startIndex = startIndex
    }

    var count: Int {
        storage.value.count - startIndex
    }

    @inline(__always)
    mutating func append(_ element: consuming Element) {
        storage.value.append(element)
    }

    mutating func withNestedStack<R: ~Copyable>(
        _ body: (consuming ScratchStack<Element>) -> R
    ) -> R {
        let child = ScratchStack(storage: &storage.value)
        return body(consume child)
    }

    @inline(__always)
    consuming func consume(
        _ body: (inout InputSpan<Element>) -> Void
    ) {
        storage.value.consumeLast(count) { span in
            body(&span)
        }
    }

    deinit {
        assert(
            count == 0,
            "scratch frame escaped with unconsumed elements"
        )
    }
}

struct ScratchStackSource<Element: ~Copyable>: ~Copyable {
    private var storage: UniqueArray<Element>

    init(initialCapacity: Int) {
        storage = UniqueArray(capacity: initialCapacity)
    }

    mutating func withStack<R: ~Copyable>(
        _ body: (consuming ScratchStack<Element>) -> R
    ) -> R {
        let frame = ScratchStack(storage: &storage)
        let result = body(consume frame)
        return result
    }
}
