/// A protocol for defining view transitions during appearance and disappearance.
///
/// Conform to this protocol to create custom transitions that animate views
/// as they appear and disappear from the view hierarchy.
///
/// ## Creating Custom Transitions
///
/// Define a transition by implementing the ``body(content:phase:)`` method:
///
/// ```swift
/// struct ScaleTransition: Transition {
///     func body(content: Content, phase: TransitionPhase) -> some View {
///         content
///             .opacity(phase.isIdentity ? 1 : 0)
///             .scaleEffect(phase.isIdentity ? 1 : 0.5)
///     }
/// }
/// ```
///
/// ## Applying Transitions
///
/// Apply transitions to views using the `transition` modifier:
///
/// ```swift
/// if isVisible {
///     Text("Hello")
///         .transition(.fade)
/// }
/// ```
public protocol Transition {
    /// The type of view produced by the transition.
    associatedtype Body: View

    /// A placeholder representing the content being transitioned.
    typealias Content = PlaceholderContentView<Self>

    /// Creates the transitioned view for the given phase.
    ///
    /// Implement this method to modify the content based on the transition phase.
    /// The content should appear normal when `phase` is ``TransitionPhase/identity``,
    /// and modified for appearance/disappearance in the other phases.
    ///
    /// - Parameters:
    ///   - content: The view to apply the transition to.
    ///   - phase: The current phase of the transition.
    /// - Returns: A view with the transition effects applied.
    @ContentBuilder func body(content: Content, phase: TransitionPhase) -> Body
}

/// The phase of a view transition.
///
/// `TransitionPhase` indicates where a view is in its appearance or disappearance animation.
public enum TransitionPhase: Equatable, Sendable {
    /// The view is about to appear.
    ///
    /// Use this phase to set up the initial appearance state before animating to ``identity``.
    case willAppear

    /// The view is in its normal, visible state.
    ///
    /// This is the target state for appearance animations and the initial state
    /// for disappearance animations.
    case identity

    /// The view has disappeared.
    ///
    /// This is the final state for disappearance animations.
    case didDisappear

    /// Whether the phase represents the normal, visible state.
    ///
    /// Returns `true` only when the phase is ``identity``.
    public var isIdentity: Bool {
        self == .identity
    }

    /// A numeric representation of the transition phase.
    ///
    /// Returns:
    /// - `-1.0` for ``willAppear``
    /// - `0.0` for ``identity``
    /// - `1.0` for ``didDisappear``
    ///
    /// Useful for interpolating values across the transition:
    ///
    /// ```swift
    /// let scale = 1.0 + phase.value * 0.2  // Scale from 0.8 to 1.0 to 1.2
    /// ```
    public var value: Double {
        switch self {
        case .willAppear: -1.0
        case .identity: 0.0
        case .didDisappear: 1.0
        }
    }
}
