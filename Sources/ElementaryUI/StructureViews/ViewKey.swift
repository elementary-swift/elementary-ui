public struct _ViewKey: Hashable {
    @usableFromInline
    let value: _AnyHashable

    @inlinable
    public init<Value: Hashable>(_ value: Value) {
        self.value = _AnyHashable(value)
    }
}

#if !hasFeature(Embedded)
extension _ViewKey: CustomStringConvertible {
    public var description: String {
        value.box._baseDescription
    }
}
#endif
