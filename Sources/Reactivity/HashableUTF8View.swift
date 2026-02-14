@usableFromInline
package struct HashableUTF8View: Hashable, Sendable {
    @usableFromInline
    let raw: Substring.UTF8View

    @inlinable
    package init(_ raw: Substring.UTF8View) {
        self.raw = raw
    }

    @inlinable
    package init(_ string: String) {
        self.raw = string[...].utf8
    }

    package var stringValue: String {
        String(Substring(raw))
    }

    @inlinable
    package static func == (lhs: HashableUTF8View, rhs: HashableUTF8View) -> Bool {
        lhs.raw.elementsEqual(rhs.raw)
    }

    @inlinable
    package func hash(into hasher: inout Hasher) {
        raw.withContiguousStorageIfAvailable {
            hasher.combine(bytes: UnsafeRawBufferPointer($0))
        }
    }
}
