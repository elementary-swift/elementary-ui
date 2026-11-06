import Reactivity

package extension ReactiveObject {
    static var environmentKey: EnvironmentValues._Key<Self> {
        EnvironmentValues._Key(_$typeID)
    }

    static var _$typeID: PropertyID {
        .init(ObjectIdentifier(self))
    }
}

public extension Environment {
    init(_: V.Type = V.self) where V: ReactiveObject {
        self.init(ObjectStorageReader(V.self))
    }

    init<O: ReactiveObject>(_: O.Type = O.self) where V == O? {
        self.init(ObjectStorageReader(V.self))
    }
}

struct ObjectStorageReader<Value> {
    let propertyID: PropertyID
    let read: (_EnvironmentSlot?) -> Value

    init(_: Value.Type) where Value: ReactiveObject {
        propertyID = Value._$typeID
        read = { slot in
            guard let slot else { fatalError("No value for \(Value._$typeID) in environment") }
            return slot.value[as: Value.self]
        }
    }

    init<O: ReactiveObject>(_: Value.Type) where Value == O? {
        propertyID = O._$typeID
        read = { slot in
            slot.map { $0.value[as: O.self] }
        }
    }
}
