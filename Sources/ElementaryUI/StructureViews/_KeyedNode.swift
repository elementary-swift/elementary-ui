public struct _KeyedNode {
    private var keys: [_ViewKey]
    private var children: [MountRoot]
    private var leavingChildren: LeavingChildrenTracker = .init()
    private let viewContext: _ViewContext

    init(keys: [_ViewKey], children: [MountRoot], context: borrowing _ViewContext) {
        assert(keys.count == children.count)
        self.keys = keys
        self.children = children
        self.viewContext = copy context
    }

    init<Node: _Reconcilable>(
        keys: [_ViewKey],
        context: borrowing _ViewContext,
        ctx: inout _CommitContext,
        makeNode: (Int, borrowing _ViewContext, inout _CommitContext) -> Node
    ) {
        self.keys = keys
        self.viewContext = copy context
        self.children = []
        self.children.reserveCapacity(keys.count)

        let transaction = context.mountRoot.inheritedTransaction()
        for index in keys.indices {
            let root = MountRoot(
                mountedFrom: context,
                transaction: transaction,
                ctx: &ctx,
                create: { context, ctx in
                    AnyReconcilable(makeNode(index, context, &ctx))
                }
            )
            self.children.append(root)
        }
    }

    init<Node: _Reconcilable>(
        key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext,
        makeNode: (borrowing _ViewContext, inout _CommitContext) -> Node
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
        makeNode: @escaping (borrowing _ViewContext, inout _CommitContext) -> Node,
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
        as: Node.Type = Node.self,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _CommitContext) -> Node,
        patchNode: (Int, inout Node, inout _TransactionContext) -> Void
    ) {
        assertNoPendingRoots()

        guard !newKeys.isEmpty else {
            fastRemoveAll(context: &context)
            return
        }

        let newKeysArray = Array(newKeys)
        var pendingMounts: [MountRoot] = []

        guard !(keys.isEmpty && leavingChildren.entries.isEmpty) else {
            keys = newKeysArray
            children.removeAll(keepingCapacity: true)
            children.reserveCapacity(keys.count)

            for index in keys.indices {
                viewContext.parentElement?.reportChangedChildren(.elementAdded, tx: &context)
                let root = MountRoot(
                    pending: viewContext,
                    transaction: context.transaction,
                    transitionPhase: .willAppear,
                    create: { viewContext, ctx in
                        AnyReconcilable(makeNode(index, viewContext, &ctx))
                    }
                )
                children.append(root)
                pendingMounts.append(root)
            }

            schedulePendingMountIfNeeded(&pendingMounts, context: &context)
            return
        }

        if leavingChildren.entries.isEmpty, keys.count == newKeysArray.count, keys.elementsEqual(newKeysArray) {
            for index in children.indices {
                let child = children[index]
                precondition(!child.isPending, "double patch of pending MountRoot in keyed stable-patch path")

                let patched = child.withMountedNode(as: Node.self) { node in
                    patchNode(index, &node, &context)
                }
                precondition(patched, "expected mounted child during stable keyed patch")
            }

            schedulePendingMountIfNeeded(&pendingMounts, context: &context)
            return
        }

        let diff = newKeysArray.difference(from: keys).inferringMoves()
        keys = newKeysArray

        if !diff.isEmpty {
            var moversCache: [Int: MountRoot] = [:]

            for change in diff {
                switch change {
                case let .remove(offset, element: key, associatedWith: movedTo):
                    let root = children.remove(at: offset)

                    if movedTo != nil {
                        root.apply(.markAsMoved, &context)
                        moversCache[offset] = root
                    } else {
                        root.apply(.startRemoval, &context)
                        viewContext.parentElement?.reportChangedChildren(.elementMoved, tx: &context)
                        leavingChildren.append(key, atIndex: offset, value: root)
                    }
                case let .insert(offset, element: key, associatedWith: movedFrom):
                    let root: MountRoot

                    if let movedFrom {
                        logTrace("move \(key) from \(movedFrom) to \(offset)")
                        guard let moved = moversCache.removeValue(forKey: movedFrom) else {
                            preconditionFailure("mover not found in cache")
                        }
                        root = moved
                    } else {
                        viewContext.parentElement?.reportChangedChildren(.elementAdded, tx: &context)
                        root = MountRoot(
                            pending: viewContext,
                            transaction: context.transaction,
                            transitionPhase: .willAppear,
                            create: { viewContext, ctx in
                                AnyReconcilable(makeNode(offset, viewContext, &ctx))
                            }
                        )
                        pendingMounts.append(root)
                    }

                    children.insert(root, at: offset)
                    leavingChildren.reflectInsertionAt(offset)
                }
            }

            precondition(moversCache.isEmpty, "mover cache is not empty")
        }

        for index in children.indices {
            let child = children[index]
            if child.isPending {
                // Newly inserted roots in this pass are mounted in commit and
                // intentionally not patched before mount.
                continue
            }

            let patched = child.withMountedNode(as: Node.self) { node in
                patchNode(index, &node, &context)
            }
            precondition(patched, "expected mounted child during keyed patch")
        }

        schedulePendingMountIfNeeded(&pendingMounts, context: &context)
    }

    mutating func fastRemoveAll(context: inout _TransactionContext) {
        viewContext.parentElement?.reportChangedChildren(.elementMoved, tx: &context)

        for index in children.indices {
            let root = children[index]
            root.apply(.startRemoval, &context)
            leavingChildren.append(keys[index], atIndex: index, value: root)
        }

        keys.removeAll()
        children.removeAll()
    }

    private mutating func schedulePendingMountIfNeeded(
        _ pendingMounts: inout [MountRoot],
        context: inout _TransactionContext
    ) {
        guard !pendingMounts.isEmpty else { return }

        let roots = pendingMounts
        context.scheduler.addCommitAction { ctx in
            for root in roots {
                root.mount(&ctx)
            }
        }
        pendingMounts.removeAll(keepingCapacity: true)
    }

    private func assertNoPendingRoots() {
        let hasPendingChildren = children.contains { $0.isPending }
        let hasPendingLeaving = leavingChildren.entries.contains { $0.value.isPending }
        precondition(
            !hasPendingChildren && !hasPendingLeaving,
            "double patch of pending MountRoot in _KeyedNode"
        )
    }
}

extension _KeyedNode: _Reconcilable {
    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        for child in children {
            child.apply(op, &tx)
        }
    }

    public mutating func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        var lIndex = 0
        var nextInsertionPoint = leavingChildren.insertionIndex(for: 0)

        for cIndex in children.indices {
            if nextInsertionPoint == cIndex {
                let removed = leavingChildren.commitAndCheckRemoval(at: lIndex, ops: &ops, context: &context)
                if !removed { lIndex += 1 }
                nextInsertionPoint = leavingChildren.insertionIndex(for: lIndex)
            }

            children[cIndex].collectChildren(&ops, &context)
        }

        while nextInsertionPoint != nil {
            let removed = leavingChildren.commitAndCheckRemoval(at: lIndex, ops: &ops, context: &context)
            if !removed { lIndex += 1 }
            nextInsertionPoint = leavingChildren.insertionIndex(for: lIndex)
        }
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        for child in children {
            child.unmount(&context)
        }
        children.removeAll()

        for entry in leavingChildren.entries {
            entry.value.unmount(&context)
        }
        leavingChildren.entries.removeAll()
    }
}

private extension _KeyedNode {
    struct LeavingChildrenTracker {
        struct Entry {
            let key: _ViewKey
            var originalMountIndex: Int
            var value: MountRoot
        }

        var entries: [Entry] = []

        func insertionIndex(for index: Int) -> Int? {
            guard index < entries.count else { return nil }
            return entries[index].originalMountIndex
        }

        mutating func append(_ key: _ViewKey, atIndex index: Int, value: MountRoot) {
            let newEntry = Entry(key: key, originalMountIndex: index, value: value)
            if let insertIndex = entries.firstIndex(where: { $0.originalMountIndex > index }) {
                entries.insert(newEntry, at: insertIndex)
            } else {
                entries.append(newEntry)
            }
        }

        mutating func reflectInsertionAt(_ index: Int) {
            shiftEntriesFromIndexUpwards(index, by: 1)
        }

        mutating func commitAndCheckRemoval(
            at index: Int,
            ops: inout _ContainerLayoutPass,
            context: inout _CommitContext
        ) -> Bool {
            let isRemovalCommitted = ops.withRemovalTracking { ops in
                entries[index].value.collectChildren(&ops, &context)
            }

            if isRemovalCommitted {
                let entry = entries.remove(at: index)
                shiftEntriesFromIndexUpwards(entry.originalMountIndex, by: -1)
                entry.value.unmount(&context)
                return true
            } else {
                return false
            }
        }

        private mutating func shiftEntriesFromIndexUpwards(_ index: Int, by amount: Int) {
            for i in entries.indices where entries[i].originalMountIndex >= index {
                entries[i].originalMountIndex += amount
            }
        }
    }
}
