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

    /// Sets the background color of the view.
    ///
    /// Use this modifier to fill the background of a view with a solid color.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Colored background" }
    ///     .backgroundColor(.rgb(255, 0, 0))
    ///
    /// // With alpha transparency
    /// div { "Semi-transparent" }
    ///     .backgroundColor(.rgba(0, 0, 255, 0.5))
    ///
    /// // Animate color changes
    /// withAnimation {
    ///     isHighlighted.toggle()
    /// }
    /// div { "Content" }
    ///     .backgroundColor(isHighlighted ? .rgb(255, 255, 0) : .rgb(200, 200, 200))
    /// ```
    ///
    /// - Parameter color: The color to use for the background.
    /// - Returns: A view with the specified background color.
    ///
    /// - Note: Changes to background color are automatically animated when done in an animated transaction.
    public func backgroundColor(_ color: CSSColor) -> some View<Self.Tag> {
        DOMEffectView<BackgroundColorModifier, Self>(value: CSSBackgroundColor(color: color), wrapped: self)
    }

    /// Sets the foreground (text) color of the view.
    ///
    /// Use this modifier to change the color of text and other foreground content.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// p { "Red text" }
    ///     .foregroundColor(.rgb(255, 0, 0))
    ///
    /// // Animate color changes
    /// withAnimation {
    ///     isActive.toggle()
    /// }
    /// span { "Status" }
    ///     .foregroundColor(isActive ? .rgb(0, 255, 0) : .rgb(128, 128, 128))
    /// ```
    ///
    /// - Parameter color: The color to use for foreground content.
    /// - Returns: A view with the specified foreground color.
    ///
    /// - Note: Changes to foreground color are automatically animated when done in an animated transaction.
    public func foregroundColor(_ color: CSSColor) -> some View<Self.Tag> {
        DOMEffectView<ForegroundColorModifier, Self>(value: CSSForegroundColor(color: color), wrapped: self)
    }

    /// Sets the border width of the view.
    ///
    /// Use this modifier to add or change the width of a view's border.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Bordered content" }
    ///     .borderWidth(2)
    ///     .attributes(.style(["border-style": "solid"]))
    ///
    /// // Animate border width changes
    /// withAnimation {
    ///     isSelected.toggle()
    /// }
    /// div { "Item" }
    ///     .borderWidth(isSelected ? 4 : 1)
    /// ```
    ///
    /// - Parameter width: The border width in pixels.
    /// - Returns: A view with the specified border width.
    ///
    /// - Note: You may need to set `border-style` via attributes for the border to be visible.
    /// - Note: Changes to border width are automatically animated when done in an animated transaction.
    public func borderWidth(_ width: Double) -> some View<Self.Tag> {
        DOMEffectView<BorderWidthModifier, Self>(value: CSSBorderWidth(value: width), wrapped: self)
    }

    /// Sets the border color of the view.
    ///
    /// Use this modifier to change the color of a view's border.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Colored border" }
    ///     .borderWidth(2)
    ///     .borderColor(.rgb(255, 0, 0))
    ///     .attributes(.style(["border-style": "solid"]))
    ///
    /// // Animate border color changes
    /// withAnimation {
    ///     hasError.toggle()
    /// }
    /// input { }
    ///     .borderColor(hasError ? .rgb(255, 0, 0) : .rgb(200, 200, 200))
    /// ```
    ///
    /// - Parameter color: The color to use for the border.
    /// - Returns: A view with the specified border color.
    ///
    /// - Note: Changes to border color are automatically animated when done in an animated transaction.
    public func borderColor(_ color: CSSColor) -> some View<Self.Tag> {
        DOMEffectView<BorderColorModifier, Self>(value: CSSBorderColor(color: color), wrapped: self)
    }

    /// Sets the corner radius of the view.
    ///
    /// Use this modifier to round the corners of a view.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Rounded corners" }
    ///     .cornerRadius(8)
    ///
    /// // Make a circle (with equal width and height)
    /// div { }
    ///     .cornerRadius(50)
    ///
    /// // Animate corner radius changes
    /// withAnimation {
    ///     isExpanded.toggle()
    /// }
    /// div { "Card" }
    ///     .cornerRadius(isExpanded ? 16 : 4)
    /// ```
    ///
    /// - Parameter radius: The corner radius in pixels.
    /// - Returns: A view with the specified corner radius.
    ///
    /// - Note: Changes to corner radius are automatically animated when done in an animated transaction.
    public func cornerRadius(_ radius: Double) -> some View<Self.Tag> {
        DOMEffectView<CornerRadiusModifier, Self>(value: CSSCornerRadius(value: radius), wrapped: self)
    }

    /// Applies a blur effect to the view.
    ///
    /// Use this modifier to blur the contents of a view.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// img { }
    ///     .blur(radius: 5)
    ///
    /// // Animate blur changes
    /// withAnimation {
    ///     isLoading.toggle()
    /// }
    /// div { "Content" }
    ///     .blur(radius: isLoading ? 10 : 0)
    /// ```
    ///
    /// - Parameter radius: The blur radius in pixels. Use 0 for no blur.
    /// - Returns: A view with the specified blur effect.
    ///
    /// - Note: Changes to blur are automatically animated when done in an animated transaction.
    public func blur(radius: Double) -> some View<Self.Tag> {
        DOMEffectView<BlurModifier, Self>(value: CSSBlur(radius: radius), wrapped: self)
    }
}
