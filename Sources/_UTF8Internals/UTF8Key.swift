@usableFromInline
package struct UTF8Key: Hashable, Sendable {
    @usableFromInline
    let string: String

    @inline(__always)
    @inlinable
    package init(_ string: String) {
        self.string = string
    }

    @inline(__always)
    @inlinable
    package var stringValue: String {
        string
    }

    @inline(__always)
    @inlinable
    package static func == (lhs: UTF8Key, rhs: UTF8Key) -> Bool {
        lhs.string.utf8Equals(rhs.string)
    }

    @inline(__always)
    @inlinable
    package func hash(into hasher: inout Hasher) {
        hasher.combine(utf8Bytes: string)
    }
}
