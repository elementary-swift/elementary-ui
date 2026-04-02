import BasicContainers
import ContainersPreview

struct ScratchStack<Element: ~Copyable>: ~Copyable, ~Escapable {
    private var storage: Inout<UniqueArray<Element>>
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

    mutating func append(_ element: consuming Element) {
        storage.value.append(element)
    }

    mutating func withNestedFrame<R: ~Copyable>(
        _ body: (consuming ScratchStack<Element>) -> R
    ) -> R {
        let child = ScratchStack(storage: &storage.value)
        return body(consume child)
    }

    consuming func consumeFrame(
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

struct ScratchStorage<Element: ~Copyable>: ~Copyable {
    private var storage: UniqueArray<Element>? = .init()

    mutating func withFrame<R: ~Copyable>(
        _ body: (consuming ScratchStack<Element>) -> R
    ) -> R {
        guard var localStorage = storage.take() else {
            preconditionFailure("overlapping scratch root frame")
        }

        let frame = ScratchStack(storage: &localStorage)
        let result = body(consume frame)
        precondition(localStorage.isEmpty, "scratch root frame leaked elements")
        storage = consume localStorage
        return result
    }
}
