extension DOM {
    @_spi(Benchmarking)
    public struct Rect: Equatable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    @_spi(Benchmarking)
    public enum PropertyValue {
        case string(String)
        case number(Double)
        case boolean(Bool)
        case stringArray([String])
        case null
        case undefined
    }

    @_spi(Benchmarking)
    public struct PropertyAccessor {
        let _get: () -> PropertyValue?
        let _set: (PropertyValue) -> Void

        public init(
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

    @_spi(Benchmarking)
    public struct StyleAccessor {
        let _get: () -> String
        let _set: (String) -> Void

        public init(
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

    @_spi(Benchmarking)
    public struct ComputedStyleAccessor {
        let _get: (String) -> String

        public init(
            get: @escaping (String) -> String
        ) {
            self._get = get
        }

        func get(_ cssName: String) -> String {
            _get(cssName)
        }
    }
}
