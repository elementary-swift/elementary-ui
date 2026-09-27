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
    var trigger: _PhaseTrigger?
    var content: (Phase) -> Content
    var animation: (Phase) -> Animation?

    /// Creates an animator that continuously cycles through a finite sequence.
    public init(
        _ phases: some Sequence<Phase>,
        @ContentBuilder content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) {
        self.phases = Array(phases)
        self.content = content
        self.animation = animation
    }

    /// Creates an animator that runs a cycle when the trigger changes.
    ///
    /// Retriggering while targeting the second phase advances to the next phase;
    /// from any other target it redirects to the second phase. Existing motion
    /// is interrupted using the destination animation, without resetting visually.
    public init(
        _ phases: some Sequence<Phase>,
        trigger: some Equatable,
        @ContentBuilder content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) {
        self.init(phases, content: content, animation: animation)
        self.trigger = _PhaseTriggerValue(trigger)
    }

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        .init(controller: _PhaseController(view: view, context: context, ctx: &ctx))
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
    func phaseAnimator<Phase: Equatable, Content: View>(
        _ phases: some Sequence<Phase>,
        @ContentBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) -> some View<Content.Tag> {
        _PhaseModifierView(wrapped: self) { placeholderContent in
            PhaseAnimator(phases, content: { content(PlaceholderContentView(content: placeholderContent), $0) }, animation: animation)
        }
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
    func phaseAnimator<Phase: Equatable, Content: View>(
        _ phases: some Sequence<Phase>,
        trigger: some Equatable,
        @ContentBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) -> some View<Content.Tag> {
        _PhaseModifierView(wrapped: self) { placeholderContent in
            PhaseAnimator(phases, trigger: trigger, content: { content(PlaceholderContentView(content: placeholderContent), $0) }, animation: animation)
        }
    }
}

// Keep trigger erasure private to the implementation rather than adding a
// trigger generic parameter to the public container type.
class _PhaseTrigger {
    func equals(_ other: _PhaseTrigger) -> Bool { fatalError("abstract") }
}

private final class _PhaseTriggerValue<Value: Equatable>: _PhaseTrigger {
    let value: Value
    init(_ value: Value) { self.value = value }
    override func equals(_ other: _PhaseTrigger) -> Bool {
        (other as? _PhaseTriggerValue<Value>)?.value == value
    }
}

// Evaluate user content inside a function view so reactive reads remain tracked.
@View
private struct _PhaseContent<Phase, Content: View> {
    var phase: Phase?
    var content: (Phase) -> Content

    var body: Content? {
        phase.map(content)
    }
}

public struct _PhaseAnimatorNode<Phase: Equatable, Content: View>: ~Copyable, _Reconcilable {
    fileprivate let controller: _PhaseController<Phase, Content>

    public consuming func unmount(_ context: inout _CommitContext) {
        controller.unmount(&context)
    }
}

private final class _PhaseController<Phase: Equatable, Content: View> {
    typealias Rendered = _PhaseContent<Phase, Content>
    var view: PhaseAnimator<Phase, Content>
    let scheduler: Scheduler
    var child: Rendered._MountedNode?
    var index = 0
    var generation: UInt64 = 0
    var mounted = true

    init(view: PhaseAnimator<Phase, Content>, context: borrowing _ViewContext, ctx: inout _MountContext) {
        self.view = view
        self.scheduler = ctx.scheduler
        self.child = Rendered._makeNode(
            Rendered(phase: view.phases.first, content: view.content),
            context: context,
            ctx: &ctx
        )
        if view.trigger == nil { enqueueTransition(to: 1) }
    }

    func patch(_ newView: PhaseAnimator<Phase, Content>, tx: inout _TransactionContext) {
        let reset = view.phases != newView.phases || (view.trigger == nil) != (newView.trigger == nil)
        let triggered = newView.trigger.map { new in view.trigger.map { !new.equals($0) } ?? false } ?? false
        view = newView
        if reset {
            generation &+= 1
            index = 0
            tx.withModifiedTransaction({ $0 = Transaction() }, run: render(tx:))
        } else {
            render(tx: &tx)
        }
        if triggered && view.phases.count > 1 {
            enqueueTransition(to: index == 1 ? 2 % view.phases.count : 1)
        } else if reset && view.trigger == nil {
            enqueueTransition(to: 1)
        }
    }

    func render(tx: inout _TransactionContext) {
        Rendered._patchNode(
            Rendered(phase: view.phases.isEmpty ? nil : view.phases[index], content: view.content),
            node: &child!,
            tx: &tx
        )
    }

    func enqueueTransition(to target: Int) {
        guard mounted, view.phases.count > 1 else { return }
        generation &+= 1
        let token = generation
        scheduler.addEffect { [self] in
            guard self.mounted, self.generation == token else { return }
            self.scheduler.scheduleUpdate { [self] tx in
                guard self.mounted, self.generation == token else { return }
                self.index = target
                let transaction = Transaction(animation: self.view.animation(self.view.phases[target]))
                transaction.addAnimationCompletion { [self] in
                    guard self.mounted, self.generation == token else { return }
                    if self.view.trigger == nil || target != 0 {
                        self.enqueueTransition(to: (target + 1) % self.view.phases.count)
                    }
                }
                tx.withModifiedTransaction({ $0 = transaction }, run: self.render(tx:))
            }
        }
    }

    func unmount(_ context: inout _CommitContext) {
        mounted = false
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
    var makeAnimator: (PlaceholderContent) -> PhaseAnimator<Phase, Content>

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        let content = PlaceholderContent.make(view.wrapped)
        let child = PhaseAnimator._makeNode(view.makeAnimator(content), context: context, ctx: &ctx)
        return .init(state: content, child: child)
    }

    static func _patchNode(_ view: consuming Self, node: inout _MountedNode, tx: inout _TransactionContext) {
        node.state.update(view.wrapped, tx: &tx) { child, tx in
            Wrapped._patchNode(view.wrapped, node: &child, tx: &tx)
        }
        PhaseAnimator._patchNode(view.makeAnimator(node.state), node: &node.child, tx: &tx)
    }
}
