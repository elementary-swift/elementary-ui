import Reactivity

public struct _ViewKey: Equatable, Hashable, CustomStringConvertible {
    @usableFromInline
    enum Storage: Equatable, Hashable {
        case text(HashableUTF8View)
        case number(Int)
    }

    @usableFromInline
    let storage: Storage

    @inlinable
    public init(_ value: String) {
        self.storage = .text(HashableUTF8View(value))
    }

    @inlinable
    public init(_ value: Int) {
        self.storage = .number(value)
    }

    @inlinable
    public init<T: LosslessStringConvertible>(_ value: T) {
        // Keep compatibility for existing call-sites while keeping strict typed equality.
        self.storage = .text(HashableUTF8View(value.description))
    }

    public var description: String {
        switch storage {
        case .text(let text): text.stringValue
        case .number(let number): String(number)
        }
    }

    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage == rhs.storage
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
        storage.hash(into: &hasher)
    }
}
