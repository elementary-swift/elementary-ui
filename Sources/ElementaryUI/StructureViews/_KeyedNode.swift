public struct _KeyedNode: _Reconcilable {
    var keys: [_ViewKey]
    let viewContext: _ViewContext
    let container: MountRootContainer

    init(keys: [_ViewKey], children: [MountRoot], context: borrowing _ViewContext) {
        assert(keys.count == children.count)
        self.keys = keys
        self.viewContext = copy context
        self.container = MountRootContainer(roots: children)
    }

    init(
        keys: [_ViewKey],
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) {
        self.keys = keys
        self.viewContext = copy context
        self.container = MountRootContainer(roots: [])
        container.activeRoots.reserveCapacity(keys.count)

        let transaction = ctx.inheritedTransaction
        for index in keys.indices {
            let root = container.makeEagerRoot(
                context: context,
                transaction: transaction,
                ctx: &ctx,
                create: { context, mountCtx in makeNode(index, context, &mountCtx) }
            )
            container.activeRoots.append(root)
        }

        ctx.appendContainer(container)
    }

    init(
        key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) {
        self.init(
            keys: [key],
            context: context,
            ctx: &ctx,
            makeNode: { _, context, ctx in makeNode(context, &ctx) }
        )
    }

    init(_ value: some Sequence<(key: _ViewKey, node: some _Reconcilable)>, context: borrowing _ViewContext) {
        self.init(
            keys: value.map { $0.key },
            children: value.map { MountRoot(mounted: AnyReconcilable($0.node)) },
            context: context
        )
    }

    init(key: _ViewKey, child: some _Reconcilable, context: borrowing _ViewContext) {
        self.init(CollectionOfOne((key: key, node: child)), context: context)
    }

    mutating func patch<Node: _Reconcilable>(
        key: _ViewKey,
        context: inout _TransactionContext,
        as: Node.Type = Node.self,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> Node,
        patchNode: (inout Node, inout _TransactionContext) -> Void
    ) {
        patch(
            CollectionOfOne(key),
            context: &context,
            makeNode: { _, context, ctx in makeNode(context, &ctx) },
            patchNode: { _, node, tx in patchNode(&node, &tx) }
        )
    }

    mutating func patch<Node: _Reconcilable>(
        _ newKeys: some BidirectionalCollection<_ViewKey>,
        context: inout _TransactionContext,
        as type: Node.Type = Node.self,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> Node,
        patchNode: (Int, inout Node, inout _TransactionContext) -> Void
    ) {
        _ = type
        assertNoPendingRoots()

        guard !newKeys.isEmpty else {
            fastRemoveAll(context: &context)
            return
        }

        let newKeysArray = Array(newKeys)
        var didStructureChange = false
        var didScheduleLayoutChange = false

        guard !(keys.isEmpty && !container.hasLeavingRoots) else {
            keys = newKeysArray
            container.activeRoots.removeAll(keepingCapacity: true)
            container.activeRoots.reserveCapacity(keys.count)

            for index in keys.indices {
                let root = container.makePendingEnteringRoot(
                    context: viewContext,
                    transaction: context.transaction,
                    create: { viewContext, mountCtx in
                        AnyReconcilable(makeNode(index, viewContext, &mountCtx))
                    }
                )
                container.activeRoots.append(root)
            }

            didStructureChange = !container.activeRoots.isEmpty
            if didStructureChange {
                if !didScheduleLayoutChange {
                    container.reportLayoutChange(&context)
                    didScheduleLayoutChange = true
                }
            }
            return
        }

        if !container.hasLeavingRoots, keys.count == newKeysArray.count, keys.elementsEqual(newKeysArray) {
            for index in container.activeRoots.indices {
                let child = container.activeRoots[index]
                precondition(!child.isPending, "double patch of pending MountRoot in keyed stable-patch path")
                let patched = child.withMountedNode(as: Node.self) { node in patchNode(index, &node, &context) }
                precondition(patched, "expected mounted child during stable keyed patch")
            }
            return
        }

        let diff = newKeysArray.difference(from: keys).inferringMoves()
        keys = newKeysArray

        if !diff.isEmpty {
            var moversCache: [Int: MountRoot] = [:]

            for change in diff {
                switch change {
                case let .remove(offset, element: key, associatedWith: movedTo):
                    if movedTo != nil {
                        var root = container.activeRoots.remove(at: offset)
                        root.markMoved(&context)
                        moversCache[offset] = root
                    } else {
                        container.removeActiveRoot(at: offset, tx: &context)
                        didScheduleLayoutChange = true
                        _ = key
                    }
                    didStructureChange = true
                case let .insert(offset, element: key, associatedWith: movedFrom):
                    let root: MountRoot

                    if let movedFrom {
                        logTrace("move \(key) from \(movedFrom) to \(offset)")
                        guard let moved = moversCache.removeValue(forKey: movedFrom) else {
                            preconditionFailure("mover not found in cache")
                        }
                        root = moved
                    } else {
                        root = container.makePendingEnteringRoot(
                            context: viewContext,
                            transaction: context.transaction,
                            create: { viewContext, mountCtx in
                                AnyReconcilable(makeNode(offset, viewContext, &mountCtx))
                            }
                        )
                    }

                    container.insertActiveRoot(root, at: offset)
                    didStructureChange = true
                }
            }

            precondition(moversCache.isEmpty, "mover cache is not empty")
        }

        for index in container.activeRoots.indices {
            let child = container.activeRoots[index]
            if child.isPending { continue }
            let patched = child.withMountedNode(as: Node.self) { node in patchNode(index, &node, &context) }
            precondition(patched, "expected mounted child during keyed patch")
        }

        if didStructureChange {
            if !didScheduleLayoutChange {
                container.reportLayoutChange(&context)
            }
        }
    }

    mutating func fastRemoveAll(context: inout _TransactionContext) {
        guard !container.activeRoots.isEmpty else { return }
        container.removeAllActiveToLeaving(tx: &context)
        keys.removeAll()
    }

    private func assertNoPendingRoots() {
        precondition(!container.hasPendingRoots(), "double patch of pending MountRoot in _KeyedNode")
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        container.unmount(&context)
    }
}
