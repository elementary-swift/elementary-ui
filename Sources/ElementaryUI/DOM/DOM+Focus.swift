// TODO: fix this type

extension DOM {
    @_spi(Benchmarking)
    public struct FocusAccessor: ~Copyable {
        let _focus: () -> Void
        let _blur: () -> Void

        var focusSink: EventSink?
        var blurSink: EventSink?

        public init(
            focus: @escaping () -> Void,
            blur: @escaping () -> Void,
            focusSink: consuming EventSink?,
            blurSink: consuming EventSink?
        ) {
            self._focus = focus
            self._blur = blur
            self.focusSink = focusSink
            self.blurSink = blurSink
        }

        func focus() {
            _focus()
        }

        func blur() {
            _blur()
        }

        consuming func unmount() {}

        deinit {
            // nothing to do I think
        }
    }

    @_spi(Benchmarking)
    public enum FocusEvent {
        case focus
        case blur
    }
}
