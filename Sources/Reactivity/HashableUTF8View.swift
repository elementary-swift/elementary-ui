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
        let lSpan = lhs.raw.span
        let rSpan = rhs.raw.span

        guard lSpan.count == rSpan.count else { return false }
        guard !lSpan.isIdentical(to: rSpan) else { return true }

        for i in 0..<lSpan.count {
            guard lSpan[unchecked: i] == rSpan[unchecked: i] else { return false }
        }

        return true
    }

    @inlinable
    package func hash(into hasher: inout Hasher) {
        raw.withContiguousStorageIfAvailable {
            hasher.combine(bytes: UnsafeRawBufferPointer($0))
        }
    }
}
