public extension View {
    // FIXME EMBEDDED: must be public in 6.3 (crashes compiler) - recheck in 6.4
    consuming func _onEvent<Config: _DOMEventHandlerConfig>(
        _ type: Config.Type,
        handler: @escaping (Config.Event) -> Void
    ) -> some View<Tag> {
        DOMEffectView<EventHandlerModifier<Config>, Self>(value: handler, wrapped: self)
    }

    // FIXME EMBEDDED: must be public in 6.3 (crashes compiler) - recheck in 6.4
    consuming func _onEvent<Config: _DOMEventConfig>(
        _ type: Config.Type,
        handler: @escaping () -> Void
    ) -> some View<Tag> {
        DOMEffectView<EventActionModifier<Config>, Self>(value: handler, wrapped: self)
    }

    /// Adds a handler for click events with event details.
    ///
    /// Use this modifier to respond to click events and access information about
    /// the click, such as position, modifier keys, and button.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// button { "Click me" }
    ///     .onClick { event in
    ///         print("Clicked at (\(event.clientX), \(event.clientY))")
    ///         print("Shift key: \(event.shiftKey)")
    ///     }
    /// ```
    ///
    /// - Parameter handler: A closure that receives a ``MouseEvent`` when clicked.
    /// - Returns: A view that responds to click events.
    consuming func onClick(_ handler: @escaping (MouseEvent) -> Void) -> some View<Tag> {
        _onEvent(DOMEventHandlers.Click.self, handler: handler)
    }

    /// Adds a handler for click events.
    ///
    /// Use this modifier to respond to click events without needing event details.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// button { "Increment" }
    ///     .onClick {
    ///         count += 1
    ///     }
    ///
    /// div { "Toggle" }
    ///     .onClick {
    ///         withAnimation {
    ///             isExpanded.toggle()
    ///         }
    ///     }
    /// ```
    ///
    /// - Parameter handler: A closure to execute when clicked.
    /// - Returns: A view that responds to click events.
    consuming func onClick(_ handler: @escaping () -> Void) -> some View<Tag> {
        _onEvent(DOMEventHandlers.Click.self, handler: handler)
    }

    /// Adds a handler for mouse down events.
    ///
    /// Use this modifier to respond when the user presses a mouse button down
    /// on the view, before releasing it.
    ///
    /// ```swift
    /// div { "Press me" }
    ///     .onMouseDown { event in
    ///         startDragging(at: event.clientX, event.clientY)
    ///     }
    /// ```
    ///
    /// - Parameter handler: A closure that receives a ``MouseEvent`` when the mouse button is pressed.
    /// - Returns: A view that responds to mouse down events.
    consuming func onMouseDown(_ handler: @escaping (MouseEvent) -> Void) -> some View<Tag> {
        _onEvent(DOMEventHandlers.MouseDown.self, handler: handler)
    }

    /// Adds a handler for mouse move events.
    ///
    /// Use this modifier to track mouse movement over the view.
    ///
    /// ```swift
    /// div { "Hover zone" }
    ///     .onMouseMove { event in
    ///         mousePosition = (event.clientX, event.clientY)
    ///     }
    /// ```
    ///
    /// - Parameter handler: A closure that receives a ``MouseEvent`` as the mouse moves.
    /// - Returns: A view that responds to mouse move events.
    consuming func onMouseMove(_ handler: @escaping (MouseEvent) -> Void) -> some View<Tag> {
        _onEvent(DOMEventHandlers.MouseMove.self, handler: handler)
    }

    /// Adds a handler for mouse up events.
    ///
    /// Use this modifier to respond when the user releases a mouse button
    /// after pressing it down.
    ///
    /// ```swift
    /// div { "Release me" }
    ///     .onMouseUp { event in
    ///         finishDragging()
    ///     }
    /// ```
    ///
    /// - Parameter handler: A closure that receives a ``MouseEvent`` when the mouse button is released.
    /// - Returns: A view that responds to mouse up events.
    consuming func onMouseUp(_ handler: @escaping (MouseEvent) -> Void) -> some View<Tag> {
        _onEvent(DOMEventHandlers.MouseUp.self, handler: handler)
    }

    /// Adds a handler for keyboard key down events.
    ///
    /// Use this modifier to respond to keyboard input when a key is pressed.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Press a key" }
    ///     .onKeyDown { event in
    ///         if event.key == "Enter" {
    ///             submitForm()
    ///         } else if event.key == "Escape" {
    ///             cancel()
    ///         }
    ///     }
    /// ```
    ///
    /// - Parameter handler: A closure that receives a ``KeyboardEvent`` when a key is pressed.
    /// - Returns: A view that responds to key down events.
    consuming func onKeyDown(_ handler: @escaping (KeyboardEvent) -> Void) -> some View<Tag> {
        _onEvent(DOMEventHandlers.KeyDown.self, handler: handler)
    }

    /// Adds a handler for input events.
    ///
    /// Use this modifier to respond to value changes in input elements.
    /// This event fires when the user types, pastes, or otherwise changes
    /// the content of an input field.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// input()
    ///     .onInput { event in
    ///         if let value = event.targetValue {
    ///             searchQuery = value
    ///         }
    ///     }
    /// ```
    ///
    /// - Parameter handler: A closure that receives an ``InputEvent`` when the input changes.
    /// - Returns: A view that responds to input events.
    consuming func onInput(_ handler: @escaping (InputEvent) -> Void) -> some View<Tag> {
        _onEvent(DOMEventHandlers.Input.self, handler: handler)
    }
}

enum DOMEventHandlers {
    enum Click: _DOMEventHandlerConfig {
        static var name: String = "click"
        typealias Event = MouseEvent
    }

    enum MouseDown: _DOMEventHandlerConfig {
        static var name: String = "mousedown"
        typealias Event = MouseEvent
    }

    enum MouseMove: _DOMEventHandlerConfig {
        static var name: String = "mousemove"
        typealias Event = MouseEvent
    }

    enum MouseUp: _DOMEventHandlerConfig {
        static var name: String = "mouseup"
        typealias Event = MouseEvent
    }

    enum KeyDown: _DOMEventHandlerConfig {
        static var name: String = "keydown"
        typealias Event = KeyboardEvent
    }

    enum Input: _DOMEventHandlerConfig {
        static var name: String = "input"
        typealias Event = InputEvent
    }
}
