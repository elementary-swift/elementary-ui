extension DOM {
    @_spi(Benchmarking)
    public struct Animation {
        let _cancel: () -> Void
        let _update: (KeyframeEffect) -> Void

        public init(_cancel: @escaping () -> Void, _update: @escaping (KeyframeEffect) -> Void) {
            self._cancel = _cancel
            self._update = _update
        }

        func cancel() {
            _cancel()
        }

        func update(_ effect: KeyframeEffect) {
            _update(effect)
        }
    }
}

extension DOM.Animation {
    @_spi(Benchmarking)
    public enum CompositeOperation: Sendable {
        case replace
        case add
        case accumulate
    }

    @_spi(Benchmarking)
    public struct KeyframeEffect {
        var property: String
        var values: [String]
        var duration: Int  // milliseconds
        var composite: CompositeOperation

        init(property: String, values: [String], duration: Int, composite: CompositeOperation) {
            self.property = property
            self.values = values
            self.duration = duration
            self.composite = composite
        }
    }
}
