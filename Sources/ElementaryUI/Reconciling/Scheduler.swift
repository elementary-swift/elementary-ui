import BasicContainers

enum AnimationProgressResult {
    case stillRunning
    case completed
}

enum CommitAction {
    case patchText(node: DOM.Node, text: String)
    case patchAttributes(node: DOM.Node, from: _AttributeStorage, to: _AttributeStorage)
    case patchLayout(container: LayoutContainer)
    case closure((inout _CommitContext) -> Void)

    func apply(context: inout _CommitContext) {
        switch self {
        case let .patchText(node, text):
            context.dom.patchText(node, with: text)
        case let .patchAttributes(node, previousAttributes, newAttributes):
            applyHTMLAttributes(from: previousAttributes, to: newAttributes, on: node, using: context.dom)
        case let .patchLayout(container):
            container.performLayout(&context)
        case let .closure(action):
            action(&context)
        }
    }
}

final class Scheduler {
    private let dom: DOMInteractor

    let scratch = ScratchStorage()

    // Scheduler extensions are few and accessed off the patch/frame hot paths.
    // A small linear list avoids pulling dictionary machinery into Wasm builds.
    private var extensions: UniqueArray<AnyObject> = .init()

    // Work queues
    private var pendingFunctions: PendingFunctionQueue = .init()
    private var pendingUpdates: UniqueArray<(inout _TransactionContext) -> Void> = .init()
    private var pendingCommitActions: UniqueArray<CommitAction> = .init()
    private var pendingEffects: UniqueArray<() -> Void> = .init()
    private var pendingLayoutEffects: UniqueArray<(inout _CommitContext) -> Void> = .init()
    private var runningAnimations: UniqueArray<_SchedulableNode> = .init()

    // Scheduling state
    // True while an update cycle is either scheduled or currently running.
    // If this is true, callers can just enqueue work; the active cycle will pick it up.
    private var isUpdateCycleActive = false
    private var isAnimationFramePending = false
    private var currentTransaction: Transaction?

    // TODO: this is a bit hacky, ideally we can use explicit dependencies on Environment
    private var ambientContext: _TransactionContext?

    // Safety limits
    private let maxTransactionPasses = 100
    private let maxCommitPasses = 100

    // Budget for running effects per frame
    private let maxInlineEffectRounds = 30
    private let inlineEffectsTimeBudget: Double = 0.005

    private var hasReconcileWork: Bool {
        !pendingFunctions.isEmpty || !pendingUpdates.isEmpty
    }

    private var hasCommitWork: Bool {
        !pendingCommitActions.isEmpty
    }

    private var needsAnimationFrame: Bool {
        !runningAnimations.isEmpty
    }

    init(dom: DOMInteractor) {
        self.dom = dom
    }

    // MARK: - Public API

    func invalidateFunction(_ function: _SchedulableNode) {
        if ambientContext != nil {
            ambientContext!.addFunction(function)
            return
        }

        ensureUpdateCycleScheduled()

        if currentTransaction?._id != Transaction._current?._id {
            reconcile(frameTime: dom.getCurrentTime())
            currentTransaction = Transaction._current
        }

        pendingFunctions.registerFunctionForUpdate(function, transaction: currentTransaction)
    }

    func scheduleUpdate(_ callback: @escaping (inout _TransactionContext) -> Void) {
        ensureUpdateCycleScheduled()
        pendingUpdates.append(callback)
    }

    func addCommitAction(_ action: CommitAction) {
        assert(isUpdateCycleActive, "Commit actions must be added during an update cycle")
        pendingCommitActions.append(action)
    }

    func addCommitAction(_ action: @escaping (inout _CommitContext) -> Void) {
        addCommitAction(.closure(action))
    }

    // Effects are run after all pending transactions are committed
    func addEffect(_ callback: @escaping () -> Void) {
        pendingEffects.append(callback)
        ensureUpdateCycleScheduled()
    }

    /// Runs after reconciliation and all DOM commit work for this update has
    /// stabilized, while the resulting layout can be observed before paint.
    func addLayoutEffect(_ callback: @escaping (inout _CommitContext) -> Void) {
        precondition(isUpdateCycleActive)
        pendingLayoutEffects.append(callback)
    }

    func registerAnimation(_ node: _SchedulableNode) {
        runningAnimations.append(node)
        ensureAnimationFrameScheduled()
    }

    func withAmbientTransactionContext(_ context: inout _TransactionContext, _ block: () -> Void) {
        precondition(ambientContext == nil)
        ambientContext = consume context
        block()
        context = ambientContext.take()!
    }

    func withMountContext<R: ~Copyable>(
        tx: inout _TransactionContext,
        _ body: (consuming _MountContext) -> R
    ) -> R {
        self.scratch.withLayoutNodeScratchFrame { scratch in
            body(
                _MountContext(
                    nodeStack: scratch,
                    dom: dom,
                    scheduler: self,
                    currentFrameTime: tx.currentFrameTime,
                    transaction: tx.transaction
                )
            )
        }
    }

    func getOrAddExtension<Value: AnyObject>(_ type: Value.Type, make: () -> Value) -> Value {
        // TODO: think about how to do this more efficiently
        for index in extensions.indices {
            if let value = extensions[index] as? Value {
                return value
            }
        }
        let value = make()
        extensions.append(value)
        return value
    }

    // MARK: - Scheduling

    private func ensureUpdateCycleScheduled() {
        ensureUpdateCycleScheduled(afterPaint: false)
    }

    private func ensureUpdateCycleScheduled(afterPaint: Bool) {
        guard !isUpdateCycleActive else { return }
        isUpdateCycleActive = true

        if afterPaint {
            dom.setTimeout({ [self] in runUpdateCycle() }, 0)
        } else {
            dom.queueMicrotask { [self] in runUpdateCycle() }
        }
    }

    private func ensureAnimationFrameScheduled() {
        guard !isAnimationFramePending && needsAnimationFrame else { return }
        isAnimationFramePending = true
        dom.requestAnimationFrame {
            [self] rafTime in runAnimationFrame(rafTime / 1000)
        }
    }

    // MARK: - Update Cycle

    private func runUpdateCycle() {
        let startTime = dom.getCurrentTime()
        drainAllWork(frameTime: startTime)

        var rounds = 0

        while !pendingEffects.isEmpty {
            rounds += 1
            let now = dom.getCurrentTime()

            if rounds > maxInlineEffectRounds || now - startTime > inlineEffectsTimeBudget {
                break
            }

            var effects: UniqueArray<() -> Void> = .init()
            swap(&effects, &pendingEffects)
            for index in effects.indices {
                effects[index]()
            }
            drainAllWork(frameTime: now)
        }

        runLayoutEffects()

        isUpdateCycleActive = false
        currentTransaction = nil

        if !pendingEffects.isEmpty {
            ensureUpdateCycleScheduled(afterPaint: true)
        }
    }

    private func runAnimationFrame(_ frameTime: Double) {
        isAnimationFramePending = false

        let wasUpdateCycleActive = isUpdateCycleActive

        isUpdateCycleActive = true
        tickAnimations(frameTime: frameTime)
        drainAllWork(frameTime: frameTime)
        runLayoutEffects(frameTime: frameTime)
        isUpdateCycleActive = wasUpdateCycleActive

        // if animations trigger effects - move the out of rAF
        if !pendingEffects.isEmpty {
            ensureUpdateCycleScheduled(afterPaint: true)
        }

        ensureAnimationFrameScheduled()
    }

    private func drainAllWork(frameTime: Double) {
        var passes = 0

        while hasReconcileWork || hasCommitWork {
            passes += 1
            precondition(passes <= maxTransactionPasses, "Exceeded \(maxTransactionPasses) passes - infinite loop?")
            reconcile(frameTime: frameTime)
            commit(frameTime: frameTime)
        }
    }

    // MARK: - Reconcile & Commit

    private func reconcile(frameTime: Double) {
        guard hasReconcileWork else { return }

        var queue = PendingFunctionQueue()
        swap(&pendingFunctions, &queue)

        var updates: UniqueArray<(inout _TransactionContext) -> Void> = .init()
        swap(&updates, &pendingUpdates)

        var context = _TransactionContext(
            scheduler: self,
            currentTime: frameTime,
            transaction: currentTransaction,
            pendingFunctions: consume queue
        )

        for index in updates.indices {
            updates[index](&context)
        }
        context.drain()
    }

    private func commit(frameTime: Double) {
        var context = _CommitContext(dom: dom, scheduler: self, currentFrameTime: frameTime)
        var passes = 0

        while hasCommitWork {
            passes += 1
            precondition(passes <= maxCommitPasses, "Exceeded \(maxCommitPasses) commit passes - infinite loop?")

            if !pendingCommitActions.isEmpty {
                var actions: UniqueArray<CommitAction> = .init()
                swap(&actions, &pendingCommitActions)
                for index in actions.indices {
                    actions[index].apply(context: &context)
                }
            }
        }
    }

    // MARK: - Layout Effects

    private func runLayoutEffects() {
        guard !pendingLayoutEffects.isEmpty else { return }
        runLayoutEffects(frameTime: dom.getCurrentTime())
    }

    private func runLayoutEffects(frameTime: Double) {
        guard !pendingLayoutEffects.isEmpty else { return }

        var effects: UniqueArray<(inout _CommitContext) -> Void> = .init()
        swap(&effects, &pendingLayoutEffects)
        var context = _CommitContext(dom: dom, scheduler: self, currentFrameTime: frameTime)
        for index in effects.indices {
            effects[index](&context)
        }
    }

    // MARK: - Animations

    private func tickAnimations(frameTime: Double) {
        guard !runningAnimations.isEmpty else { return }

        var transaction = Transaction()
        transaction.disablesAnimation = true

        var context = _TransactionContext(
            scheduler: self,
            currentTime: frameTime,
            transaction: transaction
        )

        var index = 0
        while index < runningAnimations.count {
            if runningAnimations[index].progressAnimation(tx: &context) == .completed {
                runningAnimations.remove(at: index)
            } else {
                index += 1
            }
        }

        context.drain()
    }
}
