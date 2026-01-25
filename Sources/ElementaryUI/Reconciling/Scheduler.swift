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
    private var isUpdateCyclePending = false
    private var isAnimationFramePending = false
    private var currentTransaction: Transaction?

    // TODO: this is a bit hacky, ideally we can use explicit dependencies on Environment
    private var ambientContext: _TransactionContext?

    // Safety limits
    private let maxPasses = 100

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
        pendingCommitActions.append(action)
    }

    func addPlacementAction(_ action: @escaping (inout _CommitContext) -> Void) {
        pendingPlacements.append(action)
    }

    func afterCommit(_ callback: @escaping () -> Void) {
        pendingEffects.append(callback)
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
        guard !isUpdateCyclePending else { return }
        isUpdateCyclePending = true
        currentTransaction = Transaction._current
        dom.queueMicrotask { [self] in runUpdateCycle() }
    }

    private func ensureAnimationFrameScheduled() {
        guard !isAnimationFramePending && needsAnimationFrame else { return }
        isAnimationFramePending = true
        dom.requestAnimationFrame { [self] _ in runAnimationFrame() }
    }

    // MARK: - Update Cycle

    private func runUpdateCycle() {
        isUpdateCyclePending = false
        drainAllWork(frameTime: dom.getCurrentTime())
        currentTransaction = nil
        ensureAnimationFrameScheduled()
    }

    private func runAnimationFrame() {
        isAnimationFramePending = false
        let frameTime = dom.getCurrentTime()

        commitFLIPAnimations(frameTime: frameTime)
        tickAnimations(frameTime: frameTime)

        // Animation ticks may trigger state changes - drain any resulting work
        if hasReconcileWork || hasCommitWork {
            drainAllWork(frameTime: frameTime)
        }

        ensureAnimationFrameScheduled()
    }

    private func drainAllWork(frameTime: Double) {
        var passes = 0

        // Drain reconcile and commit work
        while hasReconcileWork || hasCommitWork {
            passes += 1
            precondition(passes <= maxPasses, "Exceeded \(maxPasses) passes - infinite loop?")
            reconcile(frameTime: frameTime)
            commit(frameTime: frameTime)
        }

        // Run effects once - any new work they trigger goes to the next cycle
        let effects = pendingEffects
        pendingEffects = []
        for effect in effects { effect() }
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
            precondition(passes <= maxPasses, "Exceeded \(maxPasses) commit passes - infinite loop?")

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

        // Efficiently progress all animations and remove completed ones
        // NOTE: this is a bit side-effecty, but should be fast
        runningAnimations.removeAll(where: { animation in
            let result = animation.progressAnimation(&context)
            return result == .completed
        })

        context.drain()
    }
}
