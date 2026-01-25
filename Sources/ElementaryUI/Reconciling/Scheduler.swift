struct AnyFunctionNode {
    let identifier: ObjectIdentifier
    let depthInTree: Int
    let runUpdate: (inout _TransactionContext) -> Void
}

enum AnimationProgressResult {
    case stillRunning
    case completed
}

struct AnyAnimatable {
    let progressAnimation: (inout _TransactionContext) -> AnimationProgressResult
}

final class Scheduler {
    private let dom: any DOM.Interactor

    // TODO: ideally this could be a completely decoupled extensions-style thing
    // TODO: make this more pluggable / strippable
    let flip: FLIPScheduler

    // Work queues
    private var pendingFunctions: PendingFunctionQueue = .init()
    private var pendingUpdates: [(inout _TransactionContext) -> Void] = []
    private var pendingCommitActions: [(inout _CommitContext) -> Void] = []
    private var pendingPlacements: [(inout _CommitContext) -> Void] = []
    private var pendingEffects: [() -> Void] = []
    private var runningAnimations: [AnyAnimatable] = []

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
        !pendingCommitActions.isEmpty || !pendingPlacements.isEmpty
    }

    private var needsAnimationFrame: Bool {
        flip.hasPendingWork || !runningAnimations.isEmpty
    }

    init(dom: any DOM.Interactor) {
        self.dom = dom
        self.flip = FLIPScheduler(dom: dom)
    }

    // MARK: - Public API

    func invalidateFunction(_ function: AnyFunctionNode) {
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

    func addCommitAction(_ action: @escaping (inout _CommitContext) -> Void) {
        assert(isUpdateCycleActive, "Commit actions must be added during an update cycle")
        pendingCommitActions.append(action)
    }

    func addPlacementAction(_ action: @escaping (inout _CommitContext) -> Void) {
        assert(isUpdateCycleActive, "Placement actions must be added during an update cycle")
        pendingPlacements.append(action)
    }

    // Effects are run after all pending transactions are committed
    func addEffect(_ callback: @escaping () -> Void) {
        pendingEffects.append(callback)
        ensureUpdateCycleScheduled()
    }

    func registerAnimation(_ animation: AnyAnimatable) {
        runningAnimations.append(animation)
        ensureAnimationFrameScheduled()
    }

    func withAmbientTransactionContext(_ context: inout _TransactionContext, _ block: () -> Void) {
        precondition(ambientContext == nil)
        ambientContext = consume context
        block()
        context = ambientContext.take()!
    }

    // MARK: - Scheduling

    private func ensureUpdateCycleScheduled() {
        ensureUpdateCycleScheduled(afterPaint: false)
    }

    private func ensureUpdateCycleScheduled(afterPaint: Bool) {
        guard !isUpdateCycleActive else { return }
        isUpdateCycleActive = true

        if afterPaint {
            dom.runNext { [self] in runUpdateCycle() }
        } else {
            dom.queueMicrotask { [self] in runUpdateCycle() }
        }
    }

    private func ensureAnimationFrameScheduled() {
        guard !isAnimationFramePending && needsAnimationFrame else { return }
        isAnimationFramePending = true
        dom.requestAnimationFrame { [self] rafTime in runAnimationFrame(rafTime / 1000) }
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

            let effects = pendingEffects
            pendingEffects = []
            for effect in effects { effect() }
            drainAllWork(frameTime: now)
        }

        isUpdateCycleActive = false
        currentTransaction = nil

        if !pendingEffects.isEmpty {
            ensureUpdateCycleScheduled(afterPaint: true)
        }
        ensureAnimationFrameScheduled()
    }

    private func runAnimationFrame(_ frameTime: Double) {
        isAnimationFramePending = false

        let wasUpdateCycleActive = isUpdateCycleActive

        isUpdateCycleActive = true
        tickAnimations(frameTime: frameTime)
        drainAllWork(frameTime: frameTime)
        isUpdateCycleActive = wasUpdateCycleActive

        // FLIP should not trigger any work - but if it would it would be outside
        commitFLIPAnimations(frameTime: frameTime)

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

        let updates = pendingUpdates
        pendingUpdates = []

        var context = _TransactionContext(
            scheduler: self,
            currentTime: frameTime,
            transaction: currentTransaction,
            pendingFunctions: consume queue
        )

        for update in updates { update(&context) }
        context.drain()
    }

    private func commit(frameTime: Double) {
        var context = _CommitContext(dom: dom, scheduler: self, currentFrameTime: frameTime)
        var passes = 0

        while hasCommitWork {
            passes += 1
            precondition(passes <= maxCommitPasses, "Exceeded \(maxCommitPasses) commit passes - infinite loop?")

            if !pendingCommitActions.isEmpty {
                let actions = pendingCommitActions
                pendingCommitActions = []
                for action in actions { action(&context) }
            }

            if !pendingPlacements.isEmpty {
                let placements = pendingPlacements
                pendingPlacements = []
                for action in placements.reversed() { action(&context) }
            }
        }
    }

    // MARK: - Animations

    private func commitFLIPAnimations(frameTime: Double) {
        guard flip.hasPendingWork else { return }
        var context = _CommitContext(dom: dom, scheduler: self, currentFrameTime: frameTime)
        flip.commitScheduledAnimations(context: &context)
    }

    private func tickAnimations(frameTime: Double) {
        guard !runningAnimations.isEmpty else { return }

        var transaction = Transaction()
        transaction.disablesAnimation = true

        var context = _TransactionContext(
            scheduler: self,
            currentTime: frameTime,
            transaction: transaction
        )

        runningAnimations.removeAll(where: { animation in
            let result = animation.progressAnimation(&context)
            return result == .completed
        })

        context.drain()
    }
}
