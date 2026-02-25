import Reactivity

public struct _ViewKey: Equatable, Hashable, CustomStringConvertible {

    // NOTE: this was an enum once, but maybe we don't need this? in any case, let's keep the option for mutiple values here open
    @usableFromInline
    let _value: HashableUTF8View

    @inlinable
    public init(_ value: String) {
        self._value = HashableUTF8View(value)
    }

    @inlinable
    public init<T: LosslessStringConvertible>(_ value: T) {
        self._value = HashableUTF8View(value.description)
    }

    public var description: String {
        _value.stringValue
    }

    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._value == rhs._value
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
        _value.hash(into: &hasher)
    }
}
