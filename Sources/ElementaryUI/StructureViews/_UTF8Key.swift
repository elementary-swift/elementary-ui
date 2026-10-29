import _UTF8Internals

/// A string key compared by its UTF-8 bytes, used by the deprecated `key` APIs.
@usableFromInline
struct _UTF8Key: Hashable, Sendable {
    @usableFromInline
    let key: UTF8Key

    @inlinable
    init(_ value: some LosslessStringConvertible) {
        key = UTF8Key(value.description)
    }
}

#if !hasFeature(Embedded)
extension _UTF8Key: CustomStringConvertible {
    @usableFromInline
    var description: String { key.stringValue }
}
#endif
