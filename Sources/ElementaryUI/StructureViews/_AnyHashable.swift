/// A type-erased hashable value. Values of different types never compare equal.
@usableFromInline
struct _AnyHashable: Hashable {
    @usableFromInline
    let box: any _AnyHashableBox

    @inlinable
    init<Value: Hashable>(_ value: Value) {
        box = _ConcreteHashableBox(base: value)
    }

    @inlinable
    static func == (lhs: _AnyHashable, rhs: _AnyHashable) -> Bool {
        lhs.box._isEqual(to: rhs.box)
    }

    @inlinable
    func hash(into hasher: inout Hasher) {
        box._hash(into: &hasher)
    }
}

@usableFromInline
protocol _AnyHashableBox {
    func _isEqual(to other: any _AnyHashableBox) -> Bool
    func _hash(into hasher: inout Hasher)
    #if !hasFeature(Embedded)
    var _baseDescription: String { get }
    #endif
}

@usableFromInline
struct _ConcreteHashableBox<Base: Hashable>: _AnyHashableBox {
    @usableFromInline
    let base: Base

    @inlinable
    init(base: Base) {
        self.base = base
    }

    @inlinable
    func _isEqual(to other: any _AnyHashableBox) -> Bool {
        guard let other = other as? Self else { return false }
        return base == other.base
    }

    @inlinable
    func _hash(into hasher: inout Hasher) {
        base.hash(into: &hasher)
    }

    #if !hasFeature(Embedded)
    @usableFromInline
    var _baseDescription: String { "\(base)" }
    #endif
}
