final class MountRoot {
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

    struct TransitionParticipant {
        let patchPhase: (TransitionPhase, inout _TransactionContext) -> Void
        let defaultAnimation: Animation?
        let isStillMounted: () -> Bool
    }

    private var state: State

    private var transitionSignal: TransitionPhase?
    var transactionAnimation: Animation?
    var transactionDisablesAnimation: Bool

    init(
        mounted node: consuming AnyReconcilable? = nil,
        transaction: Transaction? = nil,
        transitionPhase: TransitionPhase? = nil
    ) {
        self.state = .mounted(.init(node: node, layoutNodes: [], status: .unchanged))
        self.transitionSignal = transitionPhase
        self.transactionAnimation = transaction?.animation
        self.transactionDisablesAnimation = transaction?.disablesAnimation ?? false
    }

    init(
        pending seedContext: borrowing _ViewContext,
        transaction: Transaction,
        transitionPhase: TransitionPhase? = nil,
        create: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
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
        ctx: inout _MountContext,
        create: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) {
        self.state = .mounted(.init(node: nil, layoutNodes: [], status: .unchanged))
        self.transitionSignal = transitionPhase
        self.transactionAnimation = transaction.animation
        self.transactionDisablesAnimation = transaction.disablesAnimation

        var childContext = copy seedContext
        childContext.mountRoot = self
        let (node, layoutNodes) = ctx.withChildContext { (ctx: consuming _MountContext) in
            let node = create(childContext, &ctx)
            let layoutNodes = ctx.takeLayoutNodes()
            return (node, layoutNodes)
        }
        self.state = .mounted(.init(node: node, layoutNodes: layoutNodes, status: .unchanged))
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

        var mountContext = _MountContext(ctx: ctx)
        let node = create(childContext, &mountContext)
        let layoutNodes = mountContext.takeLayoutNodes()
        state = .mounted(.init(node: node, layoutNodes: layoutNodes, status: .added))
    }

    // MARK: - Transition compatibility (temporary no-op ownership)

    func consumeTransitionPhase(defaultAnimation: Animation?) -> TransitionPhase {
        _ = defaultAnimation
        let signal = transitionSignal
        transitionSignal = nil
        return signal ?? .identity
    }

    func reserveTransitionParticipant() -> UInt64? { nil }

    func registerTransitionParticipant(
        claimID: UInt64,
        defaultAnimation: Animation?,
        patchPhase: @escaping (TransitionPhase, inout _TransactionContext) -> Void,
        isStillMounted: @escaping () -> Bool,
        ctx _: inout _MountContext
    ) {
        _ = claimID
        _ = defaultAnimation
        _ = patchPhase
        _ = isStillMounted
    }

    // MARK: - Structure lifecycle

    func startRemoval(_ tx: inout _TransactionContext, handle: LayoutContainer.Handle?) {
        switch state {
        case .pending:
            state = .unmounted
        case .unmounted:
            break
        case .mounted(var mounted):
            mounted.status = .removed
            for element in mountedElementReferences(mounted.layoutNodes) {
                handle?.reportLeavingElement(element, &tx)
            }
            state = .mounted(mounted)
        }
    }

    func cancelRemoval(_ tx: inout _TransactionContext, handle: LayoutContainer.Handle?) {
        guard case .mounted(var mounted) = state else { return }
        if mounted.status == .removed {
            mounted.status = .moved
            for element in mountedElementReferences(mounted.layoutNodes) {
                handle?.reportReenteringElement(element, &tx)
            }
            state = .mounted(mounted)
        }
    }

    func markMoved(_ tx: inout _TransactionContext) {
        guard case .mounted(var mounted) = state else { return }
        mounted.status = .moved
        state = .mounted(mounted)
    }

    func collect(into ops: inout LayoutPass, _ context: inout _CommitContext) {
        switch state {
        case .unmounted:
            return
        case .pending:
            mount(&context)
            collect(into: &ops, &context)
        case .mounted(var mounted):
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

    func unmount(_ context: inout _CommitContext) {
        switch state {
        case .mounted(let mounted):
            mounted.node?.unmount(&context)
        case .pending, .unmounted:
            break
        }

        state = .unmounted
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
