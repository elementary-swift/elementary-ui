import Reactivity

extension String {
    @inline(__always)
    @inlinable
    func utf8Equals(_ other: borrowing String) -> Bool {
        self._utf8Equals(other)
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
