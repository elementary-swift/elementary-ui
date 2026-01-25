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
    private var dom: any DOM.Interactor

    // Reconciliation queues
    private var pendingFunctionsQueue: PendingFunctionQueue = .init()
    private var pendingUpdates: [(inout _TransactionContext) -> Void] = []

    // Commit queues
    private var commitActions: [(inout _CommitContext) -> Void] = []
    private var placements: [(inout _CommitContext) -> Void] = []

    // Post-commit callbacks (onChange, onAppear, onDisappear)
    private var afterCommitCallbacks: [() -> Void] = []

    // Continuous animations
    private var runningAnimations: [AnyAnimatable] = []

    // FLIP scheduler
    // TODO: ideally this could be a completely decoupled extensions-style thing, but for now it's just here
    let flip: FLIPScheduler

    // State
    private var isUpdateCyclePending: Bool = false
    private var isAnimationFramePending: Bool = false
    private var currentTransaction: Transaction?

    // For environment changes during reconciliation
    // TODO: this is a bit hacky, ideally we can use explicit dependencies on Environment
    private var ambientTransactionContext: _TransactionContext?

    // Safety limits
    private let maxTransactionsPerCycle = 100
    private let maxCommitPasses = 100

    private var needsAnimationFrame: Bool {
        flip.hasPendingWork || !runningAnimations.isEmpty
    }

    init(dom: any DOM.Interactor) {
        self.dom = dom
        // TODO: make this more pluggable / strippable
        self.flip = FLIPScheduler(dom: dom)
    }

    /// Invalidate a view function for re-evaluation (reactive: state has changed)
    func invalidateFunction(_ function: AnyFunctionNode) {
        // NOTE: this is a bit of a hack to scheduel function in the same transaction run if environment values change
        // we currently uses the same Reactivity tracking for environment changes, but they always happen during reconciliation
        guard ambientTransactionContext == nil else {
            ambientTransactionContext!.addFunction(function)
            return
        }

        // If no cycle pending and queues empty, start a new one
        if !isUpdateCyclePending && pendingFunctionsQueue.isEmpty && pendingUpdates.isEmpty {
            isUpdateCyclePending = true
            currentTransaction = Transaction._current
            dom.queueMicrotask { [self] in
                self.runUpdateCycle()
            }
        } else if currentTransaction?._id != Transaction._current?._id {
            // Transaction changed mid-batch - inline reconcile with fresh time
            reconcile(frameTime: dom.getCurrentTime())
            currentTransaction = Transaction._current
        }

        pendingFunctionsQueue.registerFunctionForUpdate(function, transaction: currentTransaction)
    }

    /// Schedule a one-shot update (imperative: I want to update something)
    func scheduleUpdate(_ callback: @escaping (inout _TransactionContext) -> Void) {
        if !isUpdateCyclePending && pendingFunctionsQueue.isEmpty && pendingUpdates.isEmpty {
            isUpdateCyclePending = true
            dom.queueMicrotask { [self] in
                self.runUpdateCycle()
            }
        }

        pendingUpdates.append(callback)
    }

    /// Schedule a DOM mutation for the commit phase
    func addCommitAction(_ action: @escaping (inout _CommitContext) -> Void) {
        commitActions.append(action)
    }

    /// Schedule a DOM structure change for the commit phase
    func addPlacementAction(_ action: @escaping (inout _CommitContext) -> Void) {
        placements.append(action)
    }

    /// Schedule a callback to run after all TXs are committed (onChange, onAppear, onDisappear)
    func afterCommit(_ callback: @escaping () -> Void) {
        afterCommitCallbacks.append(callback)
    }

    /// Register an animation for RAF callback (runs after paint, before next frame)
    func registerAnimation(_ animation: AnyAnimatable) {
        runningAnimations.append(animation)
        scheduleAnimationFrameIfNeeded()
    }

    /// Execute a block with ambient transaction context for environment changes
    func withAmbientTransactionContext(_ context: inout _TransactionContext, _ block: () -> Void) {
        precondition(ambientTransactionContext == nil, "ambient transaction context already exists")
        ambientTransactionContext = consume context
        block()
        context = ambientTransactionContext.take()!
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Update Cycle
    // ═══════════════════════════════════════════════════════════════════════

    private func runUpdateCycle() {
        isUpdateCyclePending = false
        let frameTime = dom.getCurrentTime()

        var txCount = 0

        // Loop until fully stable
        repeat {
            // Phase 1: Drain ALL pending TXs (both function updates and one-shot updates)
            while !pendingFunctionsQueue.isEmpty || !pendingUpdates.isEmpty {
                txCount += 1
                precondition(
                    txCount <= maxTransactionsPerCycle,
                    "Exceeded \(maxTransactionsPerCycle) transactions per update cycle"
                )

                reconcile(frameTime: frameTime)
                commit(frameTime: frameTime)
            }

            // Phase 2: afterCommit callbacks (only after ALL TXs drained)
            // These are simple lifecycle callbacks - if they need a new TX, they call scheduleUpdate
            if !afterCommitCallbacks.isEmpty {
                let batch = afterCommitCallbacks
                afterCommitCallbacks = []
                for callback in batch {
                    callback()
                }
            }

            // If afterCommit queued new work, loop back to Phase 1
        } while !pendingFunctionsQueue.isEmpty || !pendingUpdates.isEmpty || !afterCommitCallbacks.isEmpty

        currentTransaction = nil

        // Schedule RAF only for FLIP + animations
        scheduleAnimationFrameIfNeeded()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Reconciliation
    // ═══════════════════════════════════════════════════════════════════════

    private func reconcile(frameTime: Double) {
        var functions = PendingFunctionQueue()
        swap(&pendingFunctionsQueue, &functions)

        let updates = pendingUpdates
        pendingUpdates = []

        var context = _TransactionContext(
            scheduler: self,
            currentTime: frameTime,
            transaction: currentTransaction,
            pendingFunctions: consume functions
        )

        // Run one-shot updates first (they may queue function invalidations)
        for update in updates {
            update(&context)
        }

        context.drain()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Commit
    // ═══════════════════════════════════════════════════════════════════════

    private func commit(frameTime: Double) {
        var context = _CommitContext(
            dom: dom,
            scheduler: self,
            currentFrameTime: frameTime
        )

        var passes = 0

        // Drain until stable
        while !commitActions.isEmpty || !placements.isEmpty {
            passes += 1
            precondition(
                passes <= maxCommitPasses,
                "Exceeded \(maxCommitPasses) commit passes (infinite loop?)"
            )

            // Drain commit actions
            if !commitActions.isEmpty {
                let batch = commitActions
                commitActions = []
                for action in batch {
                    action(&context)
                }
            }

            // Drain placements (reversed for bottom-up order)
            if !placements.isEmpty {
                let batch = placements
                placements = []
                for action in batch.reversed() {
                    action(&context)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Animation Frame
    // ═══════════════════════════════════════════════════════════════════════

    private func scheduleAnimationFrameIfNeeded() {
        guard !isAnimationFramePending && needsAnimationFrame else { return }

        isAnimationFramePending = true
        dom.requestAnimationFrame { [self] _ in
            self.isAnimationFramePending = false

            let frameTime = self.dom.getCurrentTime()

            // FLIP: Measure Last + Invert (batched, one reflow)
            self.commitFLIPAnimations(frameTime: frameTime)

            // Tick all running animations (may trigger new reconciliation)
            self.tickAnimations(frameTime: frameTime)

            // Flush any commit work triggered by animations
            self.flushPendingCommitWork(frameTime: frameTime)

            self.scheduleAnimationFrameIfNeeded()
        }
    }

    private func flushPendingCommitWork(frameTime: Double) {
        // If animations triggered new work, flush it now
        guard !commitActions.isEmpty || !placements.isEmpty else { return }
        commit(frameTime: frameTime)
    }

    private func commitFLIPAnimations(frameTime: Double) {
        guard flip.hasPendingWork else { return }

        var context = _CommitContext(
            dom: dom,
            scheduler: self,
            currentFrameTime: frameTime
        )
        flip.commitScheduledAnimations(context: &context)
    }

    private func tickAnimations(frameTime: Double) {
        guard !runningAnimations.isEmpty else { return }

        var removedIndices: [Int] = []

        for index in runningAnimations.indices {
            switch progressAnimation(runningAnimations[index], frameTime: frameTime) {
            case .completed:
                removedIndices.append(index)
            case .stillRunning:
                break
            }
        }

        for index in removedIndices.reversed() {
            runningAnimations.remove(at: index)
        }
    }

    private func progressAnimation(_ animation: AnyAnimatable, frameTime: Double) -> AnimationProgressResult {
        var transaction = Transaction()
        transaction.disablesAnimation = true

        var context = _TransactionContext(
            scheduler: self,
            currentTime: frameTime,
            transaction: transaction
        )

        let result = animation.progressAnimation(&context)
        context.drain()
        return result
    }
}
