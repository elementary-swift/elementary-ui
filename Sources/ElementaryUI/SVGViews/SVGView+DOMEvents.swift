// NOTE: SVGView defines its own extensions to avoid complicated return types with conditional conformances.
// This way, both documentation and function signatures are much simpler with the minor maintenance cost of duplicating the modifiers.

public extension SVGView {
    // FIXME EMBEDDED: must be public in 6.3 (crashes compiler) - recheck in 6.4
    consuming func _onEvent<Config: _DOMEventHandlerConfig>(
        _ type: Config.Type,
        handler: @escaping (Config.Event) -> Void
    ) -> some SVGView<Tag> {
        DOMEffectView<EventHandlerModifier<Config>, Self>(value: handler, wrapped: self)
    }

    // FIXME EMBEDDED: must be public in 6.3 (crashes compiler) - recheck in 6.4
    consuming func _onEvent<Config: _DOMEventConfig>(
        _ type: Config.Type,
        handler: @escaping () -> Void
    ) -> some SVGView<Tag> {
        DOMEffectView<EventActionModifier<Config>, Self>(value: handler, wrapped: self)
    }

    /// Adds a handler for click events with event details.
    ///
    /// - Parameter handler: A closure that receives a ``MouseEvent`` when clicked.
    /// - Returns: SVG content that responds to click events.
    consuming func onClick(_ handler: @escaping (MouseEvent) -> Void) -> some SVGView<Tag> {
        _onEvent(DOMEventHandlers.Click.self, handler: handler)
    }

    /// Adds a handler for click events.
    ///
    /// - Parameter handler: A closure invoked when the element is clicked.
    /// - Returns: SVG content that responds to click events.
    consuming func onClick(_ handler: @escaping () -> Void) -> some SVGView<Tag> {
        _onEvent(DOMEventHandlers.Click.self, handler: handler)
    }

    /// Adds a handler for mouse down events.
    ///
    /// - Parameter handler: A closure that receives a ``MouseEvent`` when the mouse button is pressed.
    /// - Returns: SVG content that responds to mouse down events.
    consuming func onMouseDown(_ handler: @escaping (MouseEvent) -> Void) -> some SVGView<Tag> {
        _onEvent(DOMEventHandlers.MouseDown.self, handler: handler)
    }

    /// Adds a handler for mouse move events.
    ///
    /// - Parameter handler: A closure that receives a ``MouseEvent`` as the mouse moves.
    /// - Returns: SVG content that responds to mouse move events.
    consuming func onMouseMove(_ handler: @escaping (MouseEvent) -> Void) -> some SVGView<Tag> {
        _onEvent(DOMEventHandlers.MouseMove.self, handler: handler)
    }

    /// Adds a handler for mouse up events.
    ///
    /// - Parameter handler: A closure that receives a ``MouseEvent`` when the mouse button is released.
    /// - Returns: SVG content that responds to mouse up events.
    consuming func onMouseUp(_ handler: @escaping (MouseEvent) -> Void) -> some SVGView<Tag> {
        _onEvent(DOMEventHandlers.MouseUp.self, handler: handler)
    }

    /// Adds a handler for keyboard key down events.
    ///
    /// The element must be focusable to receive key events - set `tabindex` on it or on
    /// an ancestor.
    ///
    /// - Parameter handler: A closure that receives a ``KeyboardEvent`` when a key is pressed.
    /// - Returns: SVG content that responds to key down events.
    consuming func onKeyDown(_ handler: @escaping (KeyboardEvent) -> Void) -> some SVGView<Tag> {
        _onEvent(DOMEventHandlers.KeyDown.self, handler: handler)
    }
}
