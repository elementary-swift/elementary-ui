// NOTE: SVGView defines its own extensions to avoid complicated return types with conditional conformances.
// This way, both documentation and function signatures are much simpler with the minor maintenance cost of duplicating the modifiers.

extension SVGView {
    /// Sets the opacity of the content.
    ///
    /// - Parameter value: The opacity value, from 0 (invisible) to 1 (fully visible).
    /// - Returns: SVG content with the specified opacity.
    ///
    /// - Note: Changes to opacity are automatically animated when done in an animated transaction.
    public func opacity(_ value: Double) -> some SVGView<Self.Tag> {
        DOMEffectView<OpacityModifier, Self>(value: CSSOpacity(value: value), wrapped: self)
    }

    /// Offsets the content by the specified horizontal and vertical distances.
    ///
    /// - Parameters:
    ///   - x: The horizontal offset in pixels. Default is 0.
    ///   - y: The vertical offset in pixels. Default is 0.
    /// - Returns: SVG content offset by the specified amounts.
    ///
    /// - Note: Changes to offset are automatically animated when done in an animated transaction.
    public func offset(x: Double = 0, y: Double = 0) -> some SVGView<Self.Tag> {
        DOMEffectView<TransformModifier, Self>(value: .translation(CSSTransform.Translation(x: x, y: y)), wrapped: self)
    }

    /// Applies a Gaussian blur effect to the content.
    ///
    /// - Parameter radius: The blur radius in pixels. Use 0 for no blur.
    /// - Returns: SVG content with the specified blur effect.
    ///
    /// - Note: Changes to blur are automatically animated when done in an animated transaction.
    public func blur(radius: Double) -> some SVGView<Self.Tag> {
        DOMEffectView<FilterModifier, Self>(value: .blur(CSSFilter.Blur(radius: radius)), wrapped: self)
    }

    /// Adjusts the color saturation of the content.
    ///
    /// - Parameter amount: The saturation multiplier. 1.0 is normal, 0.0 is grayscale, >1.0 is oversaturated.
    /// - Returns: SVG content with adjusted saturation.
    ///
    /// - Note: Changes to saturation are automatically animated when done in an animated transaction.
    public func saturation(_ amount: Double) -> some SVGView<Self.Tag> {
        DOMEffectView<FilterModifier, Self>(value: .saturation(CSSFilter.Saturation(amount: amount)), wrapped: self)
    }

    /// Adjusts the brightness of the content.
    ///
    /// - Parameter amount: The brightness multiplier. 1.0 is normal, 0.0 is black, >1.0 is brighter.
    /// - Returns: SVG content with adjusted brightness.
    ///
    /// - Note: Changes to brightness are automatically animated when done in an animated transaction.
    public func brightness(_ amount: Double) -> some SVGView<Self.Tag> {
        DOMEffectView<FilterModifier, Self>(value: .brightness(CSSFilter.Brightness(amount: amount)), wrapped: self)
    }
}
