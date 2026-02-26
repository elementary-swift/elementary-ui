extension DOM {
    @_spi(Benchmarking)
    public struct FocusAccessor: ~Copyable {
        let _focus: () -> Void
        let _blur: () -> Void
        let _unmount: () -> Void

        public init(focus: @escaping () -> Void, blur: @escaping () -> Void, unmount: @escaping () -> Void) {
            self._focus = focus
            self._blur = blur
            self._unmount = unmount
        }

        func focus() {
            _focus()
        }

        func blur() {
            _blur()
        }

        consuming func unmount() {}

        deinit {
            _unmount()
        }
    }

    @_spi(Benchmarking)
    public enum FocusEvent {
        case focus
        case blur
    }
}
