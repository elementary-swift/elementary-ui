extension String {
    @inline(__always)
    @inlinable
    func utf8Equals(_ other: borrowing String) -> Bool {
        let lSpan = self.utf8.span
        let rSpan = other.utf8.span

        guard lSpan.count == rSpan.count else { return false }
        guard !lSpan.isIdentical(to: rSpan) else { return true }

        for i in 0..<lSpan.count {
            guard lSpan[unchecked: i] == rSpan[unchecked: i] else { return false }
        }

        return true
    }

    @inlinable
    @inline(__always)
    static func utf8Equals(_ lhs: borrowing String, _ rhs: borrowing String) -> Bool {
        lhs.utf8Equals(rhs)
    }
}

extension String? {
    func utf8Equals(_ other: String?) -> Bool {
        switch (self, other) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return lhs.utf8Equals(rhs)
        default:
            return false
        }
    }
}
