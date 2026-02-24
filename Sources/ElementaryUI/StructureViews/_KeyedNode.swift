public final class _KeyedNode {
    private var keys: [_ViewKey]
    private var children: [AnyReconcilable?]
    private var leavingChildren: LeavingChildrenTracker = .init()
    private let viewContext: _ViewContext

    init(keys: [_ViewKey], children: [AnyReconcilable?], context: borrowing _ViewContext) {
        assert(keys.count == children.count)
        self.keys = keys
        self.children = children
        self.viewContext = copy context
    }

    convenience init(_ value: some Sequence<(key: _ViewKey, node: some _Reconcilable)>, context: borrowing _ViewContext) {
        var keys = [_ViewKey]()
        var children = [AnyReconcilable?]()

        keys.reserveCapacity(value.underestimatedCount)
        children.reserveCapacity(value.underestimatedCount)

        for entry in value {
            keys.append(entry.key)
            children.append(AnyReconcilable(entry.node))
        }

        self.init(keys: keys, children: children, context: context)
    }

    convenience init(key: _ViewKey, child: some _Reconcilable, context: borrowing _ViewContext) {
        self.init(CollectionOfOne((key: key, node: child)), context: context)
    }

    func patch<Node: _Reconcilable>(
        key: _ViewKey,
        context: inout _TransactionContext,
        as: Node.Type = Node.self,
        makeOrPatchNode: (inout Node?, borrowing _ViewContext, inout _TransactionContext) -> Void
    ) {
        patch(
            CollectionOfOne(key),
            context: &context,
            makeOrPatchNode: { _, node, context, r in makeOrPatchNode(&node, context, &r) }
        )
    }

    func patch<Node: _Reconcilable>(
        _ newKeys: some BidirectionalCollection<_ViewKey>,
        context: inout _TransactionContext,
        as: Node.Type = Node.self,
        makeOrPatchNode: (Int, inout Node?, borrowing _ViewContext, inout _TransactionContext) -> Void
    ) {
        guard !newKeys.isEmpty else {
            // fast-pass for empty key list
            self.viewContext.parentElement?.reportChangedChildren(.elementMoved, tx: &context)

            for index in children.indices {
                guard let node = children[index].take() else {
                    fatalError("unexpected nil child on collection")
                }

                node.apply(.startRemoval, &context)
                leavingChildren.append(keys[index], atIndex: index, value: node)
            }

            keys.removeAll()
            children.removeAll()

            return
        }

        let diff = newKeys.difference(from: keys).inferringMoves()
        keys = Array(newKeys)

        if !diff.isEmpty {
            var moversCache: [Int: AnyReconcilable] = [:]

            // is there a way to completely do this in-place?
            // is there a way to do this more sub-rangy?
            // anyway, this way the "move" case is a bit worse, but the rest is in place

            for change in diff {
                switch change {
                case let .remove(offset, element: key, associatedWith: movedTo):
                    guard let node = children.remove(at: offset) else {
                        fatalError("unexpected nil child on collection")
                    }

                    if movedTo != nil {
                        node.apply(.markAsMoved, &context)
                        moversCache[offset] = consume node
                    } else {
                        node.apply(.startRemoval, &context)
                        self.viewContext.parentElement?.reportChangedChildren(.elementMoved, tx: &context)
                        leavingChildren.append(key, atIndex: offset, value: node)
                    }
                case let .insert(offset, element: key, associatedWith: movedFrom):
                    var node: AnyReconcilable? = nil

                    if let movedFrom {
                        logTrace("move \(key) from \(movedFrom) to \(offset)")
                        node = moversCache.removeValue(forKey: movedFrom)
                        precondition(node != nil, "mover not found in cache")
                    }

                    children.insert(node, at: offset)
                    leavingChildren.reflectInsertionAt(offset)
                }
            }
            precondition(moversCache.isEmpty, "mover cache is not empty")
        }

        // run update / patch functions on all nodes
        for index in children.indices {
            makeOrPatchNode(index, &children[unwrapped: index, as: Node.self], self.viewContext, &context)
            assert(children[index] != nil, "unexpected nil child on collection")
        }
    }
}

extension _KeyedNode: _Reconcilable {
    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        for index in children.indices {
            children[index]?.apply(op, &tx)
        }
    }

    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        // the trick here is to efficiently interleave the leaving nodes with the active nodes to match the DOM order
        // the other trick is to stay noncopyable compatible (one fine day we will have lists, associated types and stuff like that)
        // in any case, we need to mutate in place
        var lIndex = 0
        var nextInsertionPoint = leavingChildren.insertionIndex(for: 0)

        for cIndex in children.indices {
            precondition(children[cIndex] != nil, "unexpected nil child on collection")

            if nextInsertionPoint == cIndex {
                let removed = leavingChildren.commitAndCheckRemoval(at: lIndex, ops: &ops, context: &context)
                if !removed { lIndex += 1 }
                nextInsertionPoint = leavingChildren.insertionIndex(for: lIndex)
            }

            children[cIndex]!.collectChildren(&ops, &context)
        }

        while nextInsertionPoint != nil {
            let removed = leavingChildren.commitAndCheckRemoval(at: lIndex, ops: &ops, context: &context)
            if !removed { lIndex += 1 }
            nextInsertionPoint = leavingChildren.insertionIndex(for: lIndex)
        }
    }

    public func unmount(_ context: inout _CommitContext) {
        for index in children.indices {
            children[index]?.unmount(&context)
        }

        children.removeAll()
        for entry in leavingChildren.entries {
            entry.value.unmount(&context)
        }
        leavingChildren.entries.removeAll()
    }
}

private extension _KeyedNode {
    struct LeavingChildrenTracker: ~Copyable {
        struct Entry {
            let key: _ViewKey
            var originalMountIndex: Int
            var value: AnyReconcilable
        }

        var entries: [Entry] = []

        func insertionIndex(for index: Int) -> Int? {
            guard index < entries.count else { return nil }

            return entries[index].originalMountIndex
        }

        mutating func append(_ key: _ViewKey, atIndex index: Int, value: consuming AnyReconcilable) {
            let newEntry = Entry(key: key, originalMountIndex: index, value: value)
            if let insertIndex = firstIndex(withOriginalMountIndexGreaterThan: index) {
                entries.insert(newEntry, at: insertIndex)
            } else {
                entries.append(newEntry)
            }
        }

        mutating func reflectInsertionAt(_ index: Int) {
            shiftEntriesFromIndexUpwards(index, by: 1)
        }

        mutating func commitAndCheckRemoval(at index: Int, ops: inout _ContainerLayoutPass, context: inout _CommitContext) -> Bool {
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
            guard let startIndex = firstIndex(withOriginalMountIndexAtLeast: index) else { return }

            // Mutate a contiguous suffix in place using MutableSpan.
            do {
                var span = entries.mutableSpan
                var i = startIndex
                while i < span.count {
                    span[i].originalMountIndex += amount
                    i += 1
                }
            }
        }

        private func firstIndex(withOriginalMountIndexAtLeast target: Int) -> Int? {
            var low = 0
            var high = entries.count

            while low < high {
                let mid = (low + high) >> 1
                if entries[mid].originalMountIndex < target {
                    low = mid + 1
                } else {
                    high = mid
                }
            }

            return low < entries.count ? low : nil
        }

        private func firstIndex(withOriginalMountIndexGreaterThan target: Int) -> Int? {
            var low = 0
            var high = entries.count

            while low < high {
                let mid = (low + high) >> 1
                if entries[mid].originalMountIndex <= target {
                    low = mid + 1
                } else {
                    high = mid
                }
            }

            return low < entries.count ? low : nil
        }
    }
}

extension [AnyReconcilable?] {
    subscript<Node: _Reconcilable>(unwrapped index: Index, as type: Node.Type = Node.self) -> Node? {
        get {
            self[index]?.unwrap(as: Node.self)
        }
        _modify {
            var slot = self[index].take()?.unwrap(as: Node.self)
            yield &slot
            self[index] = slot.map(AnyReconcilable.init)
        }
        set {
            self[index] = newValue.map(AnyReconcilable.init)
        }
    }
}
