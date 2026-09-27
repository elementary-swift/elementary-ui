/// A type-erased transition.
///
/// Use `AnyTransition` when a transition needs to be stored or passed without
/// preserving its concrete type. You can also attach a default animation to
/// the transition:
///
/// ```swift
/// let fade = AnyTransition(FadeTransition())
///     .animation(.easeInOut)
/// ```
public struct AnyTransition {
    private class Box {
        let animation: Animation?

        init(animation: Animation?) {
            self.animation = animation
        }

        func makeNode(
            phase: TransitionPhase,
            context: borrowing _ViewContext,
            ctx: inout _MountContext,
            content: PlaceholderContent
        ) -> AnyReconcilable {
            fatalError("abstract")
        }

        func patchNode(
            to phase: TransitionPhase,
            node: inout AnyReconcilable,
            tx: inout _TransactionContext,
            content: PlaceholderContent
        ) {
            fatalError("abstract")
        }

        func withAnimation(_ animation: Animation?) -> Box {
            fatalError("abstract")
        }
    }

    private final class ConcreteBox<T: Transition>: Box {
        let transition: T

        init(_ transition: T, animation: Animation?) {
            self.transition = transition
            super.init(animation: animation)
        }

        override func makeNode(
            phase: TransitionPhase,
            context: borrowing _ViewContext,
            ctx: inout _MountContext,
            content: PlaceholderContent
        ) -> AnyReconcilable {
            let placeholder = PlaceholderContentView<T>(content: content)
            return AnyReconcilable(
                T.Body._makeNode(
                    transition.body(content: placeholder, phase: phase),
                    context: context,
                    ctx: &ctx
                )
            )
        }

        override func patchNode(
            to phase: TransitionPhase,
            node: inout AnyReconcilable,
            tx: inout _TransactionContext,
            content: PlaceholderContent
        ) {
            let placeholder = PlaceholderContentView<T>(content: content)
            node.modify(as: T.Body._MountedNode.self) { node in
                T.Body._patchNode(
                    transition.body(content: placeholder, phase: phase),
                    node: &node,
                    tx: &tx
                )
            }
        }

        override func withAnimation(_ animation: Animation?) -> Box {
            ConcreteBox(transition, animation: animation)
        }
    }

    private let box: Box

    /// The animation used when the surrounding transaction has no animation.
    public var animation: Animation? {
        box.animation
    }

    /// Erases the concrete type of a transition.
    public init<T: Transition>(
        _ transition: T,
        animation: Animation? = nil
    ) {
        self.box = ConcreteBox(transition, animation: animation)
    }

    private init(box: Box) {
        self.box = box
    }

    /// Returns this transition with the given default animation.
    public func animation(_ animation: Animation?) -> AnyTransition {
        AnyTransition(
            box: box.withAnimation(animation)
        )
    }

    func makeNode(
        phase: TransitionPhase,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        content: PlaceholderContent
    ) -> AnyReconcilable {
        box.makeNode(
            phase: phase,
            context: context,
            ctx: &ctx,
            content: content
        )
    }

    func patchNode(
        to phase: TransitionPhase,
        node: inout AnyReconcilable,
        tx: inout _TransactionContext,
        content: PlaceholderContent
    ) {
        box.patchNode(
            to: phase,
            node: &node,
            tx: &tx,
            content: content
        )
    }
}
