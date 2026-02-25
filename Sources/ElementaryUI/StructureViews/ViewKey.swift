import Reactivity

public struct _ViewKey: Equatable, Hashable, CustomStringConvertible {

    // NOTE: this was an enum once, but maybe we don't need this? in any case, let's keep the option for mutiple values here open
    @usableFromInline
    let _value: HashableUTF8View

    @inlinable
    public init(_ value: String) {
        self._value = HashableUTF8View(value)
    }

    public init<T: LosslessStringConvertible>(_ value: T) {
        self._value = HashableUTF8View(value.description)
    }

    public var description: String {
        _value.stringValue
    }
}
