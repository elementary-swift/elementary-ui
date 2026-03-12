final class MountRoot {
    private enum State {
        case pending(
            seedContext: _ViewContext,
            create: (borrowing _ViewContext, inout _CommitContext) -> AnyReconcilable
        )
        case mounted(AnyReconcilable?)
        case unmounted
    }

    struct TransitionParticipant {
        let patchPhase: (TransitionPhase, inout _TransactionContext) -> Void
        let defaultAnimation: Animation?
        let isStillMounted: () -> Bool
    }

    nonisolated(unsafe) private static var nextTransitionClaimID: UInt64 = 0

    private var state: State

    private var transitionSignal: TransitionPhase?
    var transactionAnimation: Animation?
    var transactionDisablesAnimation: Bool
    private var transitionParticipantClaimID: UInt64?
    private var transitionParticipant: TransitionParticipant?
    private var pendingEnterAnimation: Animation?
    private var removalToken: Double?

    init(
        mounted node: consuming AnyReconcilable? = nil,
        transaction: Transaction? = nil,
        transitionPhase: TransitionPhase? = nil
    ) {
        self.state = .mounted(node)
        self.transitionSignal = transitionPhase
        self.transactionAnimation = transaction?.animation
        self.transactionDisablesAnimation = transaction?.disablesAnimation ?? false
    }

    init(
        pending seedContext: borrowing _ViewContext,
        transaction: Transaction,
        transitionPhase: TransitionPhase? = nil,
        create: @escaping (borrowing _ViewContext, inout _CommitContext) -> AnyReconcilable
    ) {
        self.state = .pending(seedContext: copy seedContext, create: create)
        self.transitionSignal = transitionPhase
        self.transactionAnimation = transaction.animation
        self.transactionDisablesAnimation = transaction.disablesAnimation
    }

    init(
        mountedFrom seedContext: borrowing _ViewContext,
        transaction: Transaction,
        transitionPhase: TransitionPhase? = nil,
        ctx: inout _CommitContext,
        create: (borrowing _ViewContext, inout _CommitContext) -> AnyReconcilable
    ) {
        self.state = .mounted(nil)
        self.transitionSignal = transitionPhase
        self.transactionAnimation = transaction.animation
        self.transactionDisablesAnimation = transaction.disablesAnimation

        var childContext = copy seedContext
        childContext.mountRoot = self
        self.state = .mounted(create(childContext, &ctx))
    }

    func inheritedTransaction() -> Transaction {
        var transaction = Transaction(animation: transactionAnimation)
        transaction.disablesAnimation = transactionDisablesAnimation
        return transaction
    }

    var isPending: Bool {
        if case .pending = state { return true }
        return false
    }

    func mount(_ ctx: inout _CommitContext) {
        guard case let .pending(seedContext, create) = state else { return }

        var childContext = seedContext
        childContext.mountRoot = self

        state = .mounted(create(childContext, &ctx))
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
            tx.withModifiedTransaction(
                {
                    $0.animation = enterAnimation
                },
                run: { tx in
                    participant.patchPhase(.identity, &tx)
                }
            )
        }
    }

    func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        switch state {
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
            mountedNode?.apply(op, &tx)
        }
    }

    func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        switch state {
        case .mounted(let node):
            guard let node else { return }
            node.collectChildren(&ops, &context)
        case .pending:
            preconditionFailure("pending MountRoot reached collectChildren")
        case .unmounted:
            return
        }
    }

    func unmount(_ context: inout _CommitContext) {
        switch state {
        case .mounted(let node):
            node?.unmount(&context)
        case .pending, .unmounted:
            break
        }

        state = .unmounted
        transitionParticipantClaimID = nil
        transitionParticipant = nil
        pendingEnterAnimation = nil
        removalToken = nil
    }

    @discardableResult
    func withMountedNode<Node: _Reconcilable>(
        as type: Node.Type = Node.self,
        _ body: (inout Node) -> Void
    ) -> Bool {
        guard case .mounted(let node) = state, let node else { return false }
        node.modify(as: Node.self, body)
        return true
    }

    private func applyPending(_ op: _ReconcileOp) {
        switch op {
        case .startRemoval:
            state = .unmounted
            transitionParticipantClaimID = nil
        case .cancelRemoval, .markAsMoved, .markAsLeaving:
            assertionFailure("apply(\(op)) on pending MountRoot")
        }
    }

    private func startRemoval(_ tx: inout _TransactionContext) {
        guard let participant = transitionParticipant, participant.isStillMounted() else {
            mountedNode?.apply(.startRemoval, &tx)
            return
        }

        guard
            let transitionAnimation = effectiveAnimation(
                defaultAnimation: participant.defaultAnimation,
                transaction: tx.transaction
            )
        else {
            mountedNode?.apply(.startRemoval, &tx)
            return
        }

        tx.withModifiedTransaction(
            {
                $0.animation = transitionAnimation
            },
            run: { tx in
                mountedNode?.apply(.markAsLeaving, &tx)
                participant.patchPhase(.didDisappear, &tx)
            }
        )

        removalToken = tx.currentFrameTime
        tx.transaction.addAnimationCompletion(criteria: .removed) { [scheduler = tx.scheduler, frameTime = removalToken] in
            guard self.removalToken == frameTime else { return }
            scheduler.scheduleUpdate { tx in
                self.mountedNode?.apply(.startRemoval, &tx)
            }
        }
    }

    private func cancelRemoval(_ tx: inout _TransactionContext) {
        removalToken = nil
        mountedNode?.apply(.cancelRemoval, &tx)

        guard let participant = transitionParticipant, participant.isStillMounted() else { return }
        participant.patchPhase(.identity, &tx)
    }

    private var mountedNode: AnyReconcilable? {
        guard case .mounted(let node) = state else { return nil }
        return node
    }

    private func effectiveAnimation(defaultAnimation: Animation?, transaction: Transaction? = nil) -> Animation? {
        let disablesAnimation = transaction?.disablesAnimation ?? transactionDisablesAnimation
        guard !disablesAnimation else { return nil }

        return transaction?.animation ?? transactionAnimation ?? defaultAnimation
    }
}

final class _MountRootList {
    var entries: [_MountRootEntry]

    init() {
        self.entries = []
    }
}

struct _MountRootEntry {
    var nodeContainer: NodeContainer
}

enum MountedNode {
    case mountRoot(_MountRootList)
    case domNode(DOM.Node)
}

struct NodeContainer {
    enum Entry {
        case staticNode(DOM.Node)
        case dynamicNode(any DynamicNode)
    }

    let nodes: [Entry]
}

protocol DynamicNode {
    var count: Int { get }
    func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext)
}
