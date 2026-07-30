/// A transition that fades views in and out by animating opacity.
///
/// The fade transition animates a view's opacity between 0 (invisible) and 1 (visible).
/// It's one of the most commonly used transitions.
///
/// ## Usage
///
/// ```swift
/// if isVisible {
///     div { "Hello, world!" }
///         .transition(.fade)
/// }
/// ```
public struct FadeTransition: Transition {
    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.opacity(phase.isIdentity ? 1.0 : 0)
    }
}

extension Transition where Self == FadeTransition {
    /// A transition that fades views in and out.
    ///
    /// ```swift
    /// Text("Notification")
    ///     .transition(.fade)
    /// ```
    public static var fade: Self { FadeTransition() }
}

extension AnyTransition {
    /// A transition that fades views in and out.
    public static var fade: AnyTransition {
        AnyTransition(FadeTransition())
    }
}
