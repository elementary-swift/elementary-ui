protocol MountRootTransitionParticipant: AnyObject {
    var mountRootDefaultAnimation: Animation? { get }
    var mountRootIsMounted: Bool { get }
    func mountRootPatchTransitionPhase(_ phase: TransitionPhase, tx: inout _TransactionContext)
}

struct MountRootTransitionRegistrationSink {
    let register: (any MountRootTransitionParticipant) -> TransitionPhase
}

final class MountRootTransitionCoordinator {
    private var participants: [any MountRootTransitionParticipant] = []
    private var nextRemovalToken: UInt64 = 0
    private var pendingExitCompletions: Int = 0
    private var pendingEnterIdentityPatches: Int = 0
    private var deferredRemovalReady: Bool = false

    private(set) var activeRemovalToken: UInt64?
    private(set) var enteringPending: Bool
    private let transactionAnimation: Animation?
    private let transactionDisablesAnimation: Bool

    init(transaction: Transaction?, enteringPending: Bool) {
        self.transactionAnimation = transaction?.animation
        self.transactionDisablesAnimation = transaction?.disablesAnimation ?? false
        self.enteringPending = enteringPending
    }

    var isRemovalInFlight: Bool {
        activeRemovalToken != nil
    }

    func inheritedTransaction() -> Transaction {
        var transaction = Transaction(animation: transactionAnimation)
        transaction.disablesAnimation = transactionDisablesAnimation
        return transaction
    }

    func makeRegistrationSink() -> MountRootTransitionRegistrationSink {
        .init(register: { [coordinator = self] participant in
            coordinator.register(participant)
        })
    }

    func scheduleEnterIdentityIfNeeded(scheduler: Scheduler) {
        guard enteringPending else { return }
        enteringPending = false

        let shouldSchedule = pendingEnterIdentityPatches > 0
        pendingEnterIdentityPatches = 0
        guard shouldSchedule else { return }

        scheduler.scheduleUpdate { [coordinator = self] tx in
            coordinator.patchAll(.identity, tx: &tx, transaction: nil)
        }
    }

    func beginRemoval(tx: inout _TransactionContext, handle: LayoutContainer.Handle?) -> Bool {
        pruneParticipants()

        let live = participants.filter { $0.mountRootIsMounted }
        guard !live.isEmpty else {
            cancelDeferredRemovalState()
            return false
        }

        nextRemovalToken &+= 1
        let token = nextRemovalToken
        activeRemovalToken = token
        pendingExitCompletions = 0
        deferredRemovalReady = false

        for participant in live {
            let animation = effectiveAnimation(for: participant, transaction: tx.transaction)
            if let animation {
                pendingExitCompletions += 1
                let exitTx = Transaction(animation: animation)
                exitTx.addAnimationCompletion { [coordinator = self, scheduler = tx.scheduler, handle] in
                    coordinator.notifyExitAnimationCompleted(token: token, scheduler: scheduler, handle: handle)
                }
                tx.withModifiedTransaction({ $0 = exitTx }) { tx in
                    participant.mountRootPatchTransitionPhase(.didDisappear, tx: &tx)
                }
            } else {
                participant.mountRootPatchTransitionPhase(.didDisappear, tx: &tx)
            }
        }

        if pendingExitCompletions == 0 {
            activeRemovalToken = nil
            return false
        }

        return true
    }

    func cancelRemoval(tx: inout _TransactionContext) {
        cancelDeferredRemovalState()
        patchAll(.identity, tx: &tx, transaction: tx.transaction)
    }

    func consumeDeferredRemovalReadySignal() -> Bool {
        let isReady = deferredRemovalReady
        deferredRemovalReady = false
        return isReady
    }

    private func register(_ participant: any MountRootTransitionParticipant) -> TransitionPhase {
        pruneParticipants()
        participants.append(participant)

        let phase: TransitionPhase
        if enteringPending, effectiveAnimation(for: participant, transaction: nil) != nil {
            phase = .willAppear
            pendingEnterIdentityPatches += 1
        } else {
            phase = .identity
        }
        return phase
    }

    private func patchAll(_ phase: TransitionPhase, tx: inout _TransactionContext, transaction: Transaction?) {
        pruneParticipants()
        for participant in participants where participant.mountRootIsMounted {
            let animation = effectiveAnimation(for: participant, transaction: transaction)
            if let animation {
                tx.withModifiedTransaction({
                    $0.animation = animation
                    $0.disablesAnimation = false
                }) { tx in
                    participant.mountRootPatchTransitionPhase(phase, tx: &tx)
                }
            } else {
                tx.withModifiedTransaction({ $0.animation = nil }) { tx in
                    participant.mountRootPatchTransitionPhase(phase, tx: &tx)
                }
            }
        }
    }

    private func effectiveAnimation(
        for participant: any MountRootTransitionParticipant,
        transaction: Transaction?
    ) -> Animation? {
        if let transaction {
            if transaction.disablesAnimation {
                return nil
            }
            return transaction.animation ?? participant.mountRootDefaultAnimation
        }

        if transactionDisablesAnimation {
            return nil
        }

        return transactionAnimation ?? participant.mountRootDefaultAnimation
    }

    private func notifyExitAnimationCompleted(
        token: UInt64,
        scheduler: Scheduler,
        handle: LayoutContainer.Handle?
    ) {
        guard activeRemovalToken == token else { return }
        if pendingExitCompletions > 0 {
            pendingExitCompletions -= 1
        }
        guard pendingExitCompletions == 0 else { return }

        activeRemovalToken = nil
        deferredRemovalReady = true
        scheduler.scheduleUpdate { tx in
            handle?.reportLayoutChange(&tx)
        }
    }

    private func cancelDeferredRemovalState() {
        activeRemovalToken = nil
        pendingExitCompletions = 0
        deferredRemovalReady = false
    }

    private func pruneParticipants() {
        participants.removeAll { !$0.mountRootIsMounted }
    }
}

struct MountRoot {
    private struct MountedState {
        var node: AnyReconcilable?
        var layoutNodes: [LayoutNode]
        var status: LayoutPass.Entry.Status
    }

    private enum State {
        case pending(
            seedContext: _ViewContext,
            create: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
        )
        case mounted(MountedState)
        case unmounted
    }

    private var state: State
    private let transitionCoordinator: MountRootTransitionCoordinator

    // MARK: - Initializers

    init(mounted node: consuming AnyReconcilable? = nil, transaction: Transaction? = nil) {
        self.state = .mounted(.init(node: node, layoutNodes: [], status: .unchanged))
        self.transitionCoordinator = .init(transaction: transaction, enteringPending: false)
    }

    init(
        pending seedContext: borrowing _ViewContext,
        transaction: Transaction,
        create: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) {
        self.state = .pending(seedContext: copy seedContext, create: create)
        self.transitionCoordinator = .init(transaction: transaction, enteringPending: true)
    }

    init(
        eager seedContext: borrowing _ViewContext,
        transaction: Transaction,
        ctx: inout _MountContext,
        create: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) {
        self.transitionCoordinator = .init(transaction: transaction, enteringPending: false)
        self.state = .mounted(.init(node: nil, layoutNodes: [], status: .unchanged))

        let context = copy seedContext
        let registrationSink = transitionCoordinator.makeRegistrationSink()
        let inheritedTransaction = transitionCoordinator.inheritedTransaction()
        let (node, layoutNodes) = ctx.withChildContext { (childCtx: consuming _MountContext) in
            var childCtx = childCtx
            childCtx.inheritedTransaction = inheritedTransaction
            childCtx.transitionRegistrationSink = registrationSink
            childCtx.transitionDepth = 0
            let node = create(context, &childCtx)
            let layoutNodes = childCtx.takeLayoutNodes()
            return (node, layoutNodes)
        }
        self.state = .mounted(.init(node: node, layoutNodes: layoutNodes, status: .unchanged))
    }

    var isPending: Bool {
        if case .pending = state { return true }
        return false
    }

    // MARK: - Lifecycle

    mutating func mount(_ ctx: inout _CommitContext) {
        guard case let .pending(seedContext, create) = state else { return }

        var mountContext = _MountContext(ctx: ctx)
        mountContext.inheritedTransaction = transitionCoordinator.inheritedTransaction()
        mountContext.transitionRegistrationSink = transitionCoordinator.makeRegistrationSink()
        mountContext.transitionDepth = 0
        let node = create(seedContext, &mountContext)
        let layoutNodes = mountContext.takeLayoutNodes()
        state = .mounted(.init(node: node, layoutNodes: layoutNodes, status: .added))

        transitionCoordinator.scheduleEnterIdentityIfNeeded(scheduler: ctx.scheduler)
    }

    mutating func startRemoval(_ tx: inout _TransactionContext, handle: LayoutContainer.Handle?) {
        switch state {
        case .pending:
            state = .unmounted
        case .unmounted:
            break
        case .mounted(var mounted):
            for element in mountedElementReferences(mounted.layoutNodes) {
                handle?.reportLeavingElement(element, &tx)
            }

            let shouldDeferRemoval = transitionCoordinator.beginRemoval(tx: &tx, handle: handle)
            if !shouldDeferRemoval {
                mounted.status = .removed
            }
            state = .mounted(mounted)
        }
    }

    mutating func cancelRemoval(_ tx: inout _TransactionContext, handle: LayoutContainer.Handle?) {
        guard case .mounted(var mounted) = state else { return }
        let isImmediatelyRemoved = mounted.status == .removed
        let isDeferredLeaving = transitionCoordinator.isRemovalInFlight
        guard isImmediatelyRemoved || isDeferredLeaving else { return }

        transitionCoordinator.cancelRemoval(tx: &tx)
        mounted.status = .moved
        for element in mountedElementReferences(mounted.layoutNodes) {
            handle?.reportReenteringElement(element, &tx)
        }
        state = .mounted(mounted)
    }

    mutating func markMoved(_: inout _TransactionContext) {
        guard case .mounted(var mounted) = state else { return }
        mounted.status = .moved
        state = .mounted(mounted)
    }

    mutating func collect(into ops: inout LayoutPass, _ context: inout _CommitContext) {
        switch state {
        case .unmounted:
            return
        case .pending:
            mount(&context)
            collect(into: &ops, &context)
        case .mounted(var mounted):
            if mounted.status != .removed, transitionCoordinator.consumeDeferredRemovalReadySignal() {
                mounted.status = .removed
            }

            let startIndex = ops.entries.count
            for node in mounted.layoutNodes {
                node.collect(into: &ops, context: &context)
            }

            if mounted.status != .unchanged {
                for index in startIndex..<ops.entries.count {
                    let entry = ops.entries[index]
                    ops.entries[index] = .init(kind: mounted.status, reference: entry.reference, type: entry.type)
                }
                ops.recomputeBatchFlags()

                if mounted.status == .added || mounted.status == .moved {
                    mounted.status = .unchanged
                }

                state = .mounted(mounted)
            }
        }
    }

    mutating func unmount(_ context: inout _CommitContext) {
        switch state {
        case .mounted(let mounted):
            mounted.node?.unmount(&context)
        case .pending, .unmounted:
            break
        }
        state = .unmounted
    }

    var isFullyRemoved: Bool {
        guard case .mounted(let mounted) = state else { return true }
        return mounted.status == .removed
    }

    @discardableResult
    func withMountedNode<Node: _Reconcilable>(
        as type: Node.Type = Node.self,
        _ body: (inout Node) -> Void
    ) -> Bool {
        _ = type
        guard case .mounted(let mounted) = state, let node = mounted.node else { return false }
        node.modify(as: Node.self, body)
        return true
    }

    private func mountedElementReferences(_ layoutNodes: [LayoutNode]) -> [DOM.Node] {
        var elements: [DOM.Node] = []
        for node in layoutNodes {
            switch node {
            case .elementNode(let ref):
                elements.append(ref)
            case .textNode, .container:
                break
            }
        }
        return elements
    }
}
