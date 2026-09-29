/// Animates content through an ordered sequence of phases.
///
/// Without a trigger, playback starts on mount and repeats. With a trigger,
/// playback starts when the trigger changes and stops after returning to the
/// first phase. The animation closure receives the destination phase.
///
/// ```swift
/// PhaseAnimator([false, true]) { highlighted in
///     div { "Working" }.opacity(highlighted ? 1 : 0.5)
/// } animation: { _ in
///     .easeInOut(duration: 1)
/// }
/// ```
///
/// Empty sequences render nothing; a single phase stays static. Changing the
/// sequence resets to its first phase; continuous playback restarts, while
/// triggered playback waits for another trigger change. Duplicate phases retain
/// their positions in the sequence.
///
/// Phases advance on logical animation completion. Returning `nil` from the
/// animation closure applies the phase without animation and uses ordinary
/// completion to continue. A delay applies only when an animation actually runs.
public struct PhaseAnimator<Phase: Equatable, Content: View>: View {
    public typealias Body = Never
    public typealias Tag = Content.Tag
    public typealias _MountedNode = _PhaseAnimatorNode<Phase, Content>

    var phases: [Phase]
    var trigger: AnyEquatable?
    var content: (Phase) -> Content
    var animation: (Phase) -> Animation?

    /// Creates an animator that continuously cycles through a finite sequence.
    ///
    /// - Parameters:
    ///   - phases: The ordered sequence of phases to cycle through.
    ///   - content: Builds content for the supplied phase.
    ///   - animation: Receives the destination phase and returns the animation
    ///     used to transition into it. Return `nil` to transition without animation.
    ///     Defaults to `.default`.
    public init(
        _ phases: some Sequence<Phase>,
        @ContentBuilder content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) {
        self.init(phases: Array(phases), trigger: nil, content: content, animation: animation)
    }

    /// Creates an animator that runs a cycle when the trigger changes.
    ///
    /// Retriggering while targeting the second phase advances to the next phase;
    /// from any other target it redirects to the second phase. Existing motion
    /// is interrupted using the destination animation, without resetting visually.
    ///
    /// - Parameters:
    ///   - phases: The ordered sequence of phases to cycle through.
    ///   - trigger: A value whose changes start or redirect a cycle.
    ///   - content: Builds content for the supplied phase.
    ///   - animation: Receives the destination phase and returns the animation
    ///     used to transition into it. Return `nil` to transition without animation.
    ///     Defaults to `.default`.
    public init(
        _ phases: some Sequence<Phase>,
        trigger: some Equatable,
        @ContentBuilder content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) {
        self.init(phases: Array(phases), trigger: AnyEquatable(trigger), content: content, animation: animation)
    }

    init(
        phases: [Phase],
        trigger: AnyEquatable?,
        content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation?
    ) {
        self.phases = phases
        self.trigger = trigger
        self.content = content
        self.animation = animation
    }

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        .init(controller: PhaseController(view: view, context: context, ctx: &ctx))
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.controller.patch(view, tx: &tx)
    }
}

public extension View {
    /// Continuously animates effects through a finite sequence of phases.
    /// The animation closure selects the animation for the destination phase.
    ///
    /// - Parameters:
    ///   - phases: The ordered sequence of phases to cycle through.
    ///   - content: Receives a proxy for the modified view and the phase to render.
    ///   - animation: Receives the destination phase and returns the animation
    ///     used to transition into it. Return `nil` to transition without animation.
    ///     Defaults to `.default`.
    func phaseAnimator<Phase: Equatable, Content: View>(
        _ phases: some Sequence<Phase>,
        @ContentBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) -> some View<Content.Tag> {
        _PhaseModifierView(wrapped: self, phases: Array(phases), trigger: nil, content: content, animation: animation)
    }

    /// Animates one cycle when the trigger changes, ending at the first phase.
    ///
    /// ```swift
    /// div { "Saved" }
    ///     .phaseAnimator([false, true], trigger: saveCount) { content, expanded in
    ///         content.scaleEffect(expanded ? 1.2 : 1)
    ///     }
    /// ```
    ///
    /// See ``PhaseAnimator`` for retriggering and phase-list replacement behavior.
    ///
    /// - Parameters:
    ///   - phases: The ordered sequence of phases to cycle through.
    ///   - trigger: A value whose changes start or redirect a cycle.
    ///   - content: Receives a proxy for the modified view and the phase to render.
    ///   - animation: Receives the destination phase and returns the animation
    ///     used to transition into it. Return `nil` to transition without animation.
    ///     Defaults to `.default`.
    func phaseAnimator<Phase: Equatable, Content: View>(
        _ phases: some Sequence<Phase>,
        trigger: some Equatable,
        @ContentBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) -> some View<Content.Tag> {
        _PhaseModifierView(
            wrapped: self,
            phases: Array(phases),
            trigger: AnyEquatable(trigger),
            content: content,
            animation: animation
        )
    }
}

// Type-erased equatable value, embedded compatible.
// The equator must be an instance rather than a metatype: Embedded does not
// specialize witness tables stored in existential metatypes, so static
// requirements dispatch to a deleted-method stub.
struct AnyEquatable: Equatable {
    private protocol Equating {
        func isEqual(_ lhs: any Equatable, _ rhs: any Equatable) -> Bool
    }

    private struct Equator<Value: Equatable>: Equating {
        func isEqual(_ lhs: any Equatable, _ rhs: any Equatable) -> Bool {
            guard let lhs = lhs as? Value, let rhs = rhs as? Value else { return false }
            return lhs == rhs
        }
    }

    private let value: any Equatable
    private let equator: any Equating

    init<Value: Equatable>(_ value: Value) {
        self.value = value
        self.equator = Equator<Value>()
    }

    static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        lhs.equator.isEqual(lhs.value, rhs.value)
    }
}

// Evaluate user content inside a function view so reactive reads remain tracked.
// TODO: generalize this and move it to ForEach as well maybe?
@View
private struct _PhaseContent<Phase, Content: View> {
    var phase: Phase
    var content: (Phase) -> Content

    var body: Content {
        content(phase)
    }
}

public struct _PhaseAnimatorNode<Phase: Equatable, Content: View>: ~Copyable, _Reconcilable {
    fileprivate let controller: PhaseController<Phase, Content>

    public consuming func unmount(_ context: inout _CommitContext) {
        controller.unmount(&context)
    }
}

private final class PhaseController<Phase: Equatable, Content: View> {
    private typealias Rendered = _PhaseContent<Phase, Content>?
    private var view: PhaseAnimator<Phase, Content>
    private let scheduler: Scheduler
    private var child: Rendered._MountedNode?
    private var index = 0
    private var generation: UInt64 = 0

    init(view: PhaseAnimator<Phase, Content>, context: borrowing _ViewContext, ctx: inout _MountContext) {
        self.view = view
        self.scheduler = ctx.scheduler
        self.child = Rendered._makeNode(rendered, context: context, ctx: &ctx)
        if view.trigger == nil { transition(to: 1) }
    }

    func patch(_ newView: PhaseAnimator<Phase, Content>, tx: inout _TransactionContext) {
        let oldView = view
        view = newView

        let isContinuous = newView.trigger == nil
        let restarts = oldView.phases != newView.phases || (oldView.trigger == nil) != isContinuous
        let triggered = oldView.trigger.map { $0 != newView.trigger } ?? false

        if restarts {
            generation &+= 1
            index = 0
            tx.withModifiedTransaction({ $0 = Transaction() }, run: render(tx:))
        } else {
            render(tx: &tx)
        }

        if triggered || (restarts && isContinuous) {
            transition(to: index == 1 ? 2 % view.phases.count : 1)
        }
    }

    private var rendered: Rendered {
        view.phases.isEmpty ? nil : _PhaseContent(phase: view.phases[index], content: view.content)
    }

    private func render(tx: inout _TransactionContext) {
        Rendered._patchNode(rendered, node: &child!, tx: &tx)
    }

    private func transition(to target: Int) {
        guard view.phases.count > 1 else { return }
        generation &+= 1
        let token = generation
        scheduler.scheduleUpdate { [self] tx in apply(target, token: token, tx: &tx) }
    }

    private func apply(_ target: Int, token: UInt64, tx: inout _TransactionContext) {
        guard generation == token else { return }
        index = target
        let startTime = tx.currentFrameTime
        let transaction = Transaction(animation: view.animation(view.phases[target]))
        transaction.addAnimationCompletion { [self] in
            guard generation == token, view.trigger == nil || target != 0 else { return }
            advance(after: target, token: token, startTime: startTime)
        }
        tx.withModifiedTransaction({ $0 = transaction }, run: render(tx:))
    }

    // Completions within the starting frame did not animate; route them through
    // effects so their per-cycle budget bounds chains of instant phases.
    private func advance(after target: Int, token: UInt64, startTime: Double) {
        let next = (target + 1) % view.phases.count
        scheduler.scheduleUpdate { [self] tx in
            if tx.currentFrameTime == startTime {
                scheduler.addEffect { [self] in
                    scheduler.scheduleUpdate { [self] tx in apply(next, token: token, tx: &tx) }
                }
            } else {
                apply(next, token: token, tx: &tx)
            }
        }
    }

    func unmount(_ context: inout _CommitContext) {
        generation &+= 1
        child.take()?.unmount(&context)
    }
}

/// Supplies content independently of the phase-driven body.
private struct _PhaseModifierView<Wrapped: View, Phase: Equatable, Content: View>: View {
    typealias Body = Never
    typealias Tag = Content.Tag
    typealias _MountedNode = _StatefulNode<PlaceholderContent, PhaseAnimator<Phase, Content>._MountedNode>

    var wrapped: Wrapped
    var phases: [Phase]
    var trigger: AnyEquatable?
    var content: (PlaceholderContentView<Wrapped>, Phase) -> Content
    var animation: (Phase) -> Animation?

    func animator(_ placeholder: PlaceholderContent) -> PhaseAnimator<Phase, Content> {
        PhaseAnimator(
            phases: phases,
            trigger: trigger,
            content: { [content] in content(PlaceholderContentView(content: placeholder), $0) },
            animation: animation
        )
    }

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        let placeholder = PlaceholderContent.make(view.wrapped)
        let child = PhaseAnimator._makeNode(view.animator(placeholder), context: context, ctx: &ctx)
        return .init(state: placeholder, child: child)
    }

    static func _patchNode(_ view: consuming Self, node: inout _MountedNode, tx: inout _TransactionContext) {
        node.state.update(view.wrapped, tx: &tx) { child, tx in
            Wrapped._patchNode(view.wrapped, node: &child, tx: &tx)
        }

        PhaseAnimator._patchNode(view.animator(node.state), node: &node.child, tx: &tx)
    }
}
