extension View {
    /// Sets the opacity of the view.
    ///
    /// Use this modifier to control the transparency of a view and its content.
    /// Opacity values range from 0 (fully transparent) to 1 (fully opaque).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Semi-transparent" }
    ///     .opacity(0.5)
    ///
    /// // Animate opacity changes
    /// withAnimation {
    ///     isVisible.toggle()
    /// }
    /// div { "Fading content" }
    ///     .opacity(isVisible ? 1.0 : 0.0)
    /// ```
    ///
    /// - Parameter value: The opacity value, from 0 (invisible) to 1 (fully visible).
    /// - Returns: A view with the specified opacity.
    ///
    /// - Note: Changes to opacity are automatically animated when done in an animated transaction.
    public func opacity(_ value: Double) -> some View<Self.Tag> {
        DOMEffectView<OpacityModifier, Self>(value: CSSOpacity(value: value), wrapped: self)
    }

    /// Rotates the view by the specified angle.
    ///
    /// Use this modifier to apply a 2D rotation transform to a view.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Rotated" }
    ///     .rotationEffect(.degrees(45))
    ///
    /// // Rotate around a custom anchor point
    /// div { "Spinning" }
    ///     .rotationEffect(.degrees(rotation), anchor: .topLeading)
    ///
    /// // Animate rotation
    /// withAnimation {
    ///     rotation += 90
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - angle: The angle to rotate by.
    ///   - anchor: The point around which to rotate. Default is `.center`.
    /// - Returns: A view rotated by the specified angle.
    ///
    /// - Note: Changes to rotation are automatically animated when done in an animated transaction.
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View<Self.Tag> {
        DOMEffectView<TransformModifier, Self>(value: .rotation(CSSTransform.Rotation(angle: angle, anchor: anchor)), wrapped: self)
    }

    /// Offsets the view by the specified horizontal and vertical distances.
    ///
    /// Use this modifier to move a view from its natural position without
    /// affecting the layout of other views.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Offset content" }
    ///     .offset(x: 50, y: 20)
    ///
    /// // Animate position changes
    /// withAnimation {
    ///     xPosition += 100
    /// }
    /// div { "Moving" }
    ///     .offset(x: xPosition)
    /// ```
    ///
    /// - Parameters:
    ///   - x: The horizontal offset in pixels. Default is 0.
    ///   - y: The vertical offset in pixels. Default is 0.
    /// - Returns: A view offset by the specified amounts.
    ///
    /// - Note: Changes to offset are automatically animated when done in an animated transaction.
    public func offset(x: Double = 0, y: Double = 0) -> some View<Self.Tag> {
        DOMEffectView<TransformModifier, Self>(value: .translation(CSSTransform.Translation(x: x, y: y)), wrapped: self)
    }

    @available(*, deprecated, message: "Use offset(x: Double, y: Double) instead")
    @_disfavoredOverload
    public func offset(x: Float = 0, y: Float = 0) -> some View<Self.Tag> {
        DOMEffectView<TransformModifier, Self>(value: .translation(CSSTransform.Translation(x: Double(x), y: Double(y))), wrapped: self)
    }

    /// Scales the view uniformly by the specified factor.
    ///
    /// Use this modifier to uniformly scale a view along both axes.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Scaled content" }
    ///     .scaleEffect(1.5)
    ///
    /// // Scale from a corner
    /// div { "Growing" }
    ///     .scaleEffect(scale, anchor: .topLeading)
    ///
    /// // Animate scale changes
    /// withAnimation {
    ///     scale = 2.0
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - scale: The scale factor to apply uniformly to both axes. 1.0 is the original size.
    ///   - anchor: The point around which to scale. Default is `.center`.
    /// - Returns: A view scaled by the specified factor.
    ///
    /// - Note: Changes to scale are automatically animated when done in an animated transaction.
    public func scaleEffect(_ scale: Double, anchor: UnitPoint = .center) -> some View<Self.Tag> {
        DOMEffectView<TransformModifier, Self>(value: .scale(CSSTransform.Scale(x: scale, y: scale, anchor: anchor)), wrapped: self)
    }

    /// Scales the view by the specified horizontal and vertical factors.
    ///
    /// Use this modifier to scale a view independently along each axis.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Stretched content" }
    ///     .scaleEffect(x: 2.0, y: 1.0)
    ///
    /// // Scale from a specific anchor point
    /// div { "Scaling" }
    ///     .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
    ///
    /// // Animate scale changes
    /// withAnimation {
    ///     scaleX = 1.5
    ///     scaleY = 0.5
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - x: The horizontal scale factor. 1.0 is the original width.
    ///   - y: The vertical scale factor. 1.0 is the original height.
    ///   - anchor: The point around which to scale. Default is `.center`.
    /// - Returns: A view scaled by the specified factors.
    ///
    /// - Note: Changes to scale are automatically animated when done in an animated transaction.
    public func scaleEffect(x: Double = 1, y: Double = 1, anchor: UnitPoint = .center) -> some View<Self.Tag> {
        DOMEffectView<TransformModifier, Self>(value: .scale(CSSTransform.Scale(x: x, y: y, anchor: anchor)), wrapped: self)
    }

    /// Applies a Gaussian blur effect to the view.
    ///
    /// Use this modifier to blur the content of a view.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Blurred content" }
    ///     .blur(radius: 5)
    ///
    /// // Animate blur changes
    /// withAnimation {
    ///     isBlurred.toggle()
    /// }
    /// div { "Content" }
    ///     .blur(radius: isBlurred ? 10 : 0)
    /// ```
    ///
    /// - Parameter radius: The blur radius in pixels. Use 0 for no blur.
    /// - Returns: A view with the specified blur effect.
    ///
    /// - Note: Changes to blur are automatically animated when done in an animated transaction.
    public func blur(radius: Double) -> some View<Self.Tag> {
        DOMEffectView<FilterModifier, Self>(value: .blur(CSSFilter.Blur(radius: radius)), wrapped: self)
    }

    /// Adjusts the color saturation of the view.
    ///
    /// Use this modifier to control the color intensity of a view.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Grayscale" }
    ///     .saturation(0)
    ///
    /// // Animate saturation changes
    /// withAnimation {
    ///     isDesaturated.toggle()
    /// }
    /// div { "Content" }
    ///     .saturation(isDesaturated ? 0 : 1)
    /// ```
    ///
    /// - Parameter amount: The saturation multiplier. 1.0 is normal, 0.0 is grayscale, >1.0 is oversaturated.
    /// - Returns: A view with adjusted saturation.
    ///
    /// - Note: Changes to saturation are automatically animated when done in an animated transaction.
    public func saturation(_ amount: Double) -> some View<Self.Tag> {
        DOMEffectView<FilterModifier, Self>(value: .saturation(CSSFilter.Saturation(amount: amount)), wrapped: self)
    }

    /// Adjusts the brightness of the view.
    ///
    /// Use this modifier to make a view brighter or darker.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Bright content" }
    ///     .brightness(1.5)
    ///
    /// // Animate brightness changes
    /// withAnimation {
    ///     isDimmed.toggle()
    /// }
    /// div { "Content" }
    ///     .brightness(isDimmed ? 0.5 : 1)
    /// ```
    ///
    /// - Parameter amount: The brightness multiplier. 1.0 is normal, 0.0 is black, >1.0 is brighter.
    /// - Returns: A view with adjusted brightness.
    ///
    /// - Note: Changes to brightness are automatically animated when done in an animated transaction.
    public func brightness(_ amount: Double) -> some View<Self.Tag> {
        DOMEffectView<FilterModifier, Self>(value: .brightness(CSSFilter.Brightness(amount: amount)), wrapped: self)
    }
}
