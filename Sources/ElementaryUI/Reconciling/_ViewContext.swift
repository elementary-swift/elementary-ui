public final class MountRoot {
    enum PendingOpsPolicy {
        case assertInDebug
    }

    enum MountState {
        case pending
        case mounted
        case unmounted
    }

    struct TransitionParticipant {
        let patchPhase: (TransitionPhase, inout _TransactionContext) -> Void
        let defaultAnimation: Animation?
        let isStillMounted: () -> Bool
    }

    nonisolated(unsafe) private static var nextID: UInt64 = 0
    nonisolated(unsafe) private static var nextTransitionClaimID: UInt64 = 0

    let id: UInt64

    private(set) var mountState: MountState
    private var node: AnyReconcilable?
    private var seedContext: _ViewContext?
    private var createClosure: ((borrowing _ViewContext, inout _CommitContext) -> AnyReconcilable)?

    private let pendingOpsPolicy: PendingOpsPolicy

    private var transitionSignal: TransitionPhase?
    var transactionAnimation: Animation?
    var transactionDisablesAnimation: Bool
    private var transitionParticipantClaimID: UInt64?
    private var transitionParticipant: TransitionParticipant?
    private var pendingEnterAnimation: Animation?
    private var removalToken: Double?

    init(
        transitionPhase: TransitionPhase? = nil,
        transactionAnimation: Animation? = nil,
        transactionDisablesAnimation: Bool = false,
        pendingOpsPolicy: PendingOpsPolicy = .assertInDebug
    ) {
        MountRoot.nextID &+= 1
        self.id = MountRoot.nextID
        self.mountState = .mounted
        self.pendingOpsPolicy = pendingOpsPolicy
        self.transitionSignal = transitionPhase
        self.transactionAnimation = transactionAnimation
        self.transactionDisablesAnimation = transactionDisablesAnimation
    }

    private init(
        seedContext: borrowing _ViewContext,
        transaction: Transaction,
        transitionSignal: TransitionPhase?,
        pendingOpsPolicy: PendingOpsPolicy,
        create: @escaping (borrowing _ViewContext, inout _CommitContext) -> AnyReconcilable
    ) {
        MountRoot.nextID &+= 1
        self.id = MountRoot.nextID
        self.mountState = .pending
        self.node = nil
        self.seedContext = copy seedContext
        self.createClosure = create
        self.pendingOpsPolicy = pendingOpsPolicy
        self.transitionSignal = transitionSignal
        self.transactionAnimation = transaction.animation
        self.transactionDisablesAnimation = transaction.disablesAnimation
    }

    static func from(_ transaction: Transaction, transitionPhase: TransitionPhase? = nil) -> MountRoot {
        MountRoot(
            transitionPhase: transitionPhase,
            transactionAnimation: transaction.animation,
            transactionDisablesAnimation: transaction.disablesAnimation
        )
    }

    static func pending(
        seedContext: borrowing _ViewContext,
        transaction: Transaction,
        transitionPhase: TransitionPhase? = nil,
        create: @escaping (borrowing _ViewContext, inout _CommitContext) -> AnyReconcilable
    ) -> MountRoot {
        MountRoot(
            seedContext: seedContext,
            transaction: transaction,
            transitionSignal: transitionPhase,
            pendingOpsPolicy: .assertInDebug,
            create: create
        )
    }

    static func materialized(
        seedContext: borrowing _ViewContext,
        transaction: Transaction? = nil,
        transitionPhase: TransitionPhase? = nil,
        ctx: inout _CommitContext,
        create: @escaping (borrowing _ViewContext, inout _CommitContext) -> AnyReconcilable
    ) -> MountRoot {
        let effectiveTransaction: Transaction
        if let transaction {
            effectiveTransaction = transaction
        } else {
            var inherited = Transaction(animation: seedContext.mountRoot.transactionAnimation)
            inherited.disablesAnimation = seedContext.mountRoot.transactionDisablesAnimation
            effectiveTransaction = inherited
        }

        let root = MountRoot.pending(
            seedContext: seedContext,
            transaction: effectiveTransaction,
            transitionPhase: transitionPhase,
            create: create
        )
        root.materialize(&ctx)
        return root
    }

    static func mounted(_ node: consuming AnyReconcilable) -> MountRoot {
        let root = MountRoot()
        root.node = node
        return root
    }

    var isPending: Bool {
        mountState == .pending
    }

    func updatePendingCreate(
        seedContext: borrowing _ViewContext,
        transaction: Transaction,
        create: @escaping (borrowing _ViewContext, inout _CommitContext) -> AnyReconcilable
    ) {
        guard mountState == .pending else { return }
        self.seedContext = copy seedContext
        self.createClosure = create
        self.transactionAnimation = transaction.animation
        self.transactionDisablesAnimation = transaction.disablesAnimation
    }

    func materialize(_ ctx: inout _CommitContext) {
        guard mountState == .pending else { return }
        guard let createClosure, let seedContext else {
            preconditionFailure("pending MountRoot missing create context")
        }

        var childContext = seedContext
        childContext.mountRoot = self

        node = createClosure(childContext, &ctx)
        self.seedContext = nil
        self.createClosure = nil
        self.mountState = .mounted
    }

    func consumeTransitionPhase(defaultAnimation: Animation?) -> TransitionPhase {
        let signal = transitionSignal
        transitionSignal = nil

        guard signal == .willAppear else { return signal ?? .identity }
        guard let animation = effectiveAnimation(defaultAnimation: defaultAnimation) else {
            return .identity
        }

        pendingEnterAnimation = animation
        return .willAppear
    }

    func reserveTransitionParticipant() -> UInt64? {
        guard transitionParticipant == nil, transitionParticipantClaimID == nil else { return nil }
        MountRoot.nextTransitionClaimID &+= 1
        let claimID = MountRoot.nextTransitionClaimID
        transitionParticipantClaimID = claimID
        return claimID
    }

    func registerTransitionParticipant(
        claimID: UInt64,
        defaultAnimation: Animation?,
        patchPhase: @escaping (TransitionPhase, inout _TransactionContext) -> Void,
        isStillMounted: @escaping () -> Bool,
        ctx: inout _CommitContext
    ) {
        guard transitionParticipant == nil, transitionParticipantClaimID == claimID else { return }
        transitionParticipantClaimID = nil
        transitionParticipant = .init(
            patchPhase: patchPhase,
            defaultAnimation: defaultAnimation,
            isStillMounted: isStillMounted
        )

        guard let enterAnimation = pendingEnterAnimation else { return }
        pendingEnterAnimation = nil

        ctx.scheduler.scheduleUpdate { tx in
            guard let participant = self.transitionParticipant, participant.isStillMounted() else { return }
            tx.withModifiedTransaction({
                $0.animation = enterAnimation
            }, run: { tx in
                participant.patchPhase(.identity, &tx)
            })
        }
    }

    func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        switch mountState {
        case .pending:
            applyPending(op)
            return
        case .unmounted:
            return
        case .mounted:
            break
        }

        switch op {
        case .startRemoval:
            startRemoval(&tx)
        case .cancelRemoval:
            cancelRemoval(&tx)
        case .markAsMoved, .markAsLeaving:
            node?.apply(op, &tx)
        }
    }

    func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        switch mountState {
        case .mounted:
            guard let node else {
                preconditionFailure("mounted MountRoot missing node")
            }
            node.collectChildren(&ops, &context)
        case .pending:
            preconditionFailure("pending MountRoot reached collectChildren")
        case .unmounted:
            return
        }
    }

    func unmount(_ context: inout _CommitContext) {
        switch mountState {
        case .mounted:
            node?.unmount(&context)
        case .pending, .unmounted:
            break
        }

        node = nil
        seedContext = nil
        createClosure = nil
        transitionParticipantClaimID = nil
        transitionParticipant = nil
        pendingEnterAnimation = nil
        removalToken = nil
        mountState = .unmounted
    }

    @discardableResult
    func withMountedNode<Node: _Reconcilable>(
        as type: Node.Type = Node.self,
        _ body: (inout Node) -> Void
    ) -> Bool {
        guard mountState == .mounted, let node else { return false }
        node.modify(as: Node.self, body)
        return true
    }

    private func applyPending(_ op: _ReconcileOp) {
        switch op {
        case .startRemoval:
            node = nil
            seedContext = nil
            createClosure = nil
            transitionParticipantClaimID = nil
            mountState = .unmounted
        case .cancelRemoval, .markAsMoved, .markAsLeaving:
            switch pendingOpsPolicy {
            case .assertInDebug:
                assertionFailure("apply(\(op)) on pending MountRoot")
            }
        }
    }

    private func startRemoval(_ tx: inout _TransactionContext) {
        guard let participant = transitionParticipant, participant.isStillMounted() else {
            node?.apply(.startRemoval, &tx)
            return
        }

        guard let transitionAnimation = effectiveAnimation(
            defaultAnimation: participant.defaultAnimation,
            transaction: tx.transaction
        ) else {
            node?.apply(.startRemoval, &tx)
            return
        }

        tx.withModifiedTransaction({
            $0.animation = transitionAnimation
        }, run: { tx in
            node?.apply(.markAsLeaving, &tx)
            participant.patchPhase(.didDisappear, &tx)
        })

        removalToken = tx.currentFrameTime
        tx.transaction.addAnimationCompletion(criteria: .removed) { [scheduler = tx.scheduler, frameTime = removalToken] in
            guard self.removalToken == frameTime else { return }
            scheduler.scheduleUpdate { tx in
                self.node?.apply(.startRemoval, &tx)
            }
        }
    }

    private func cancelRemoval(_ tx: inout _TransactionContext) {
        removalToken = nil
        node?.apply(.cancelRemoval, &tx)

        guard let participant = transitionParticipant, participant.isStillMounted() else { return }
        participant.patchPhase(.identity, &tx)
    }

    private func effectiveAnimation(defaultAnimation: Animation?, transaction: Transaction? = nil) -> Animation? {
        let disablesAnimation = transaction?.disablesAnimation ?? transactionDisablesAnimation
        guard !disablesAnimation else { return nil }

        return transaction?.animation ?? transactionAnimation ?? defaultAnimation
    }
}

// TODO: think about a better name for this... maybe _EnvironmentContext?
public struct _ViewContext {
    var environment: EnvironmentValues = .init()

    // built-in typed environment values (maybe using plain-old keys might be better?)
    var modifiers: DOMElementModifiers = .init()
    var layoutObservers: DOMLayoutObservers = .init()
    var functionDepth: Int = 0
    var parentElement: _ElementNode?
    var mountRoot: MountRoot = .init()

    mutating func takeModifiers() -> [any DOMElementModifier] {
        modifiers.take()
    }

    mutating func takeLayoutObservers() -> [any DOMLayoutObserver] {
        layoutObservers.take()
    }

    public static var empty: Self {
        .init()
    }
}
