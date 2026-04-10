import Reactivity

public struct _ViewKey: Equatable, Hashable, CustomStringConvertible {
    @usableFromInline
    let propertyID: PropertyID

    @inlinable
    public init(_ value: String) {
        self.propertyID = PropertyID(value)
    }

    @inlinable
    public init(_ value: Int) {
        self.propertyID = PropertyID(value)
    }

    @inlinable
    public init<T: LosslessStringConvertible>(_ value: T) {
        // Keep compatibility for existing call-sites while keeping strict typed equality.
        self.propertyID = PropertyID(value.description)
    }

    public var description: String {
        propertyID.description
    }

    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.propertyID == rhs.propertyID
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
        propertyID.hash(into: &hasher)
    }
}
