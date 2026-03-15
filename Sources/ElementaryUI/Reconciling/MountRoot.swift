struct MountRoot {
    enum PlacementRole {
        case active
        case leaving
    }

    private struct MountedState {
        var node: AnyReconcilable?
        var layoutNodes: [LayoutNode]
        var status: LayoutPass.Entry.Status
    }

    private enum PayloadState {
        case pending(
            seedContext: _ViewContext,
            create: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
        )
        case mounted(MountedState)
    }

    let key: _ViewKey
    private(set) var placementRole: PlacementRole

    private var state: PayloadState
    private var pendingPrunedBeforeMount: Bool = false
    private var transitionCoordinator: MountRootTransitionCoordinator? = nil
    private let mountTransaction: Transaction

    init(
        key: _ViewKey,
        pending seedContext: borrowing _ViewContext,
        transaction: Transaction,
        create: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) {
        self.key = key
        self.placementRole = .active
        self.mountTransaction = transaction
        self.state = .pending(seedContext: copy seedContext, create: create)
    }

    init(
        key: _ViewKey,
        eager seedContext: borrowing _ViewContext,
        ctx: inout _MountContext,
        create: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) {
        self.key = key
        self.placementRole = .active
        self.mountTransaction = ctx.transaction
        self.state = .mounted(.init(node: nil, layoutNodes: [], status: .unchanged))

        let context = copy seedContext
        let (node, mountedOutput) = ctx.withMountRootContext { (rootCtx: consuming _MountContext) in
            var rootCtx = consume rootCtx
            let node = create(context, &rootCtx)
            let mountedOutput = rootCtx.takeMountedOutput()
            return (node, mountedOutput)
        }
        self.transitionCoordinator = mountedOutput.transitionCoordinator
        self.state = .mounted(.init(node: node, layoutNodes: mountedOutput.layoutNodes, status: .unchanged))
    }

    var isActive: Bool {
        placementRole == .active
    }

    var isLeaving: Bool {
        placementRole == .leaving
    }

    var isPending: Bool {
        if case .pending = state { return true }
        return false
    }

    mutating func beginLeaving(_ tx: inout _TransactionContext, handle: LayoutContainer.Handle?) {
        placementRole = .leaving

        switch state {
        case .pending:
            pendingPrunedBeforeMount = true
        case .mounted(var mounted):
            for element in mountedElementReferences(mounted.layoutNodes) {
                handle?.reportLeavingElement(element, &tx)
            }

            let shouldDeferRemoval = transitionCoordinator?.beginRemoval(tx: &tx, handle: handle) ?? false
            if !shouldDeferRemoval {
                mounted.status = .removed
            }
            state = .mounted(mounted)
        }
    }

    mutating func reviveFromLeaving(_ tx: inout _TransactionContext, handle: LayoutContainer.Handle?) {
        guard placementRole == .leaving else { return }
        placementRole = .active

        switch state {
        case .pending:
            pendingPrunedBeforeMount = false
        case .mounted(var mounted):
            let isImmediatelyRemoved = mounted.status == .removed
            let isDeferredLeaving = transitionCoordinator?.isRemovalInFlight ?? false
            guard isImmediatelyRemoved || isDeferredLeaving else { return }

            transitionCoordinator?.cancelRemoval(tx: &tx)
            mounted.status = .moved
            for element in mountedElementReferences(mounted.layoutNodes) {
                handle?.reportReenteringElement(element, &tx)
            }
            state = .mounted(mounted)
        }
    }

    mutating func markMoved(_: inout _TransactionContext) {
        guard case .mounted(var mounted) = state else { return }
        mounted.status = .moved
        state = .mounted(mounted)
    }

    mutating func collectAndMaybePrune(into ops: inout LayoutPass, context: inout _CommitContext) -> Bool {
        switch state {
        case .pending:
            if pendingPrunedBeforeMount { return true }
            mount(&context)
            return collectAndMaybePrune(into: &ops, context: &context)
        case .mounted(var mounted):
            if mounted.status != .removed, transitionCoordinator?.consumeDeferredRemovalReadySignal() == true {
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
            }

            state = .mounted(mounted)
            return placementRole == .leaving && mounted.status == .removed
        }
    }

    @discardableResult
    mutating func patchMounted<Node: _Reconcilable>(
        as type: Node.Type = Node.self,
        _ body: (inout Node) -> Void
    ) -> Bool {
        _ = type
        precondition(placementRole == .active, "patchMounted called for leaving root")
        guard case .mounted(let mounted) = state, let node = mounted.node else { return false }
        node.modify(as: Node.self, body)
        return true
    }

    mutating func unmount(_ context: inout _CommitContext) {
        switch state {
        case .mounted(let mounted):
            mounted.node?.unmount(&context)
        case .pending:
            break
        }
        state = .mounted(.init(node: nil, layoutNodes: [], status: .removed))
        placementRole = .leaving
        pendingPrunedBeforeMount = true
    }

    private mutating func mount(_ ctx: inout _CommitContext) {
        guard case let .pending(seedContext, create) = state else { return }

        let (node, mountedOutput) = ctx.withMountContext(transaction: mountTransaction) { mountCtx in
            var mountCtx = consume mountCtx
            let node = create(seedContext, &mountCtx)
            let mountedOutput = mountCtx.takeMountedOutput()
            return (node, mountedOutput)
        }
        transitionCoordinator = mountedOutput.transitionCoordinator
        state = .mounted(.init(node: node, layoutNodes: mountedOutput.layoutNodes, status: .added))
        pendingPrunedBeforeMount = false

        transitionCoordinator?.scheduleEnterIdentityIfNeeded(scheduler: ctx.scheduler)
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
