extension DOM {
    struct Node: Hashable {
        private let id: ObjectIdentifier
        let ref: AnyObject

        init<T: AnyObject>(ref: T) {
            self.ref = ref
            self.id = ObjectIdentifier(ref)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: Node, rhs: Node) -> Bool {
            lhs.id == rhs.id
        }
    }

    struct Event {
        let ref: AnyObject
    }

    struct EventSink {
        let ref: AnyObject
    }

    struct Rect: Equatable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double

        init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    enum PropertyValue {
        case string(String)
        case number(Double)
        case boolean(Bool)
        case stringArray([String])
        case null
        case undefined
    }

    struct PropertyAccessor {
        let _get: () -> PropertyValue?
        let _set: (PropertyValue) -> Void

        init(
            get: @escaping () -> PropertyValue?,
            set: @escaping (PropertyValue) -> Void
        ) {
            self._get = get
            self._set = set
        }

        func get() -> PropertyValue? {
            _get()
        }

        func set(_ value: PropertyValue) {
            _set(value)
        }
    }

    struct StyleAccessor {
        let _get: () -> String
        let _set: (String) -> Void

        init(
            get: @escaping () -> String,
            set: @escaping (String) -> Void
        ) {
            self._get = get
            self._set = set
        }

        func get() -> String {
            _get()
        }

        func set(_ value: String) {
            _set(value)
        }
    }

    struct ComputedStyleAccessor {
        let _get: (String) -> String

        init(
            get: @escaping (String) -> String
        ) {
            self._get = get
        }

        func get(_ cssName: String) -> String {
            _get(cssName)
        }
    }
}
