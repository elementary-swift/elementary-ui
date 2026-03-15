final class MountRootContainer {
    private struct ActiveInfo {
        var root: MountRoot
        var sourceIndex: Int
        var oldActiveOffset: Int
    }

    private struct LeavingAnchor {
        var key: _ViewKey
        var sourceIndex: Int
        var anchorActiveOffset: Int
    }

    private let viewContext: _ViewContext
    private var roots: [MountRoot]
    var containerHandle: LayoutContainer.Handle?

    init(context: borrowing _ViewContext) {
        self.viewContext = copy context
        self.roots = []
    }

    func collect(into ops: inout LayoutPass, context: inout _CommitContext) {
        if containerHandle == nil { containerHandle = ops.containerHandle }

        var index = 0
        while index < roots.count {
            let shouldPrune = roots[index].collectAndMaybePrune(into: &ops, context: &context)
            if shouldPrune {
                var root = roots.remove(at: index)
                root.unmount(&context)
                continue
            }
            index += 1
        }
    }

    func unmount(_ context: inout _CommitContext) {
        for i in roots.indices { roots[i].unmount(&context) }
        roots.removeAll()
    }

    func reportLayoutChange(_ tx: inout _TransactionContext) {
        containerHandle?.reportLayoutChange(&tx)
    }

    func mount<Node: _Reconcilable>(
        key: _ViewKey,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        mount(
            keys: CollectionOfOne(key),
            ctx: &ctx,
            makeNode: { _, context, mountCtx in
                makeNode(context, &mountCtx)
            }
        )
    }

    func mount<Node: _Reconcilable>(
        keys: some Collection<_ViewKey>,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        precondition(roots.isEmpty, "mount called on non-empty MountRootContainer")
        guard !keys.isEmpty else { return }

        var mountedRoots: [MountRoot] = []
        mountedRoots.reserveCapacity(keys.underestimatedCount)

        var index = 0
        for key in keys {
            mountedRoots.append(
                makeMountRoot(
                    key: key,
                    ctx: &ctx,
                    makeNode: { context, mountCtx in
                        makeNode(index, context, &mountCtx)
                    }
                )
            )
            index += 1
        }
        roots = mountedRoots
    }

    func patch<Node: _Reconcilable>(
        keys newKeys: some BidirectionalCollection<_ViewKey>,
        tx: inout _TransactionContext,
        makeNode: @escaping (Int, borrowing _ViewContext, inout _MountContext) -> Node,
        patchNode: (Int, inout Node, inout _TransactionContext) -> Void
    ) {
        assertNoPendingRoots()

        let newKeysArray = Array(newKeys)
        let newKeyToIndex = makeKeyIndexMap(newKeysArray)

        var didStructureChange = false
        var didReportLayoutChange = false

        func reportLayoutChangeIfNeeded(
            _ tx: inout _TransactionContext,
            _ didReportLayoutChange: inout Bool
        ) {
            if !didReportLayoutChange {
                reportLayoutChange(&tx)
                didReportLayoutChange = true
            }
        }

        var activeByKey: [_ViewKey: ActiveInfo] = [:]
        activeByKey.reserveCapacity(roots.count)
        var leavingByKey: [_ViewKey: MountRoot] = [:]
        leavingByKey.reserveCapacity(roots.count)
        var leavingAnchors: [LeavingAnchor] = []
        leavingAnchors.reserveCapacity(roots.count)

        var activeOffset = 0
        for (sourceIndex, root) in roots.enumerated() {
            if root.isActive {
                precondition(activeByKey[root.key] == nil, "duplicate active key in roots: \(root.key)")
                activeByKey[root.key] = .init(
                    root: root,
                    sourceIndex: sourceIndex,
                    oldActiveOffset: activeOffset
                )
                activeOffset += 1
            } else {
                precondition(leavingByKey[root.key] == nil, "duplicate leaving key in roots: \(root.key)")
                leavingByKey[root.key] = root
                leavingAnchors.append(
                    .init(
                        key: root.key,
                        sourceIndex: sourceIndex,
                        anchorActiveOffset: activeOffset
                    )
                )
            }
        }

        let activeKeysSnapshot = Array(activeByKey.keys)
        for key in activeKeysSnapshot where newKeyToIndex[key] == nil {
            guard var removed = activeByKey.removeValue(forKey: key) else {
                preconditionFailure("missing active key during removal: \(key)")
            }
            reportLayoutChangeIfNeeded(&tx, &didReportLayoutChange)
            removed.root.beginLeaving(&tx, handle: containerHandle)
            leavingByKey[key] = removed.root
            leavingAnchors.append(
                .init(
                    key: key,
                    sourceIndex: removed.sourceIndex,
                    anchorActiveOffset: removed.oldActiveOffset
                )
            )
            didStructureChange = true
        }

        var targetActiveRoots: [MountRoot] = []
        targetActiveRoots.reserveCapacity(newKeysArray.count)

        for (newActiveOffset, key) in newKeysArray.enumerated() {
            if var reusedActive = activeByKey.removeValue(forKey: key) {
                if reusedActive.oldActiveOffset != newActiveOffset {
                    reusedActive.root.markMoved(&tx)
                    didStructureChange = true
                }
                targetActiveRoots.append(reusedActive.root)
            } else if var revived = leavingByKey.removeValue(forKey: key) {
                reportLayoutChangeIfNeeded(&tx, &didReportLayoutChange)
                revived.reviveFromLeaving(&tx, handle: containerHandle)
                targetActiveRoots.append(revived)
                didStructureChange = true
            } else {
                targetActiveRoots.append(
                    makePatchRoot(
                        key: key,
                        transaction: tx.transaction,
                        makeNode: { context, mountCtx in
                            makeNode(newActiveOffset, context, &mountCtx)
                        }
                    )
                )
                didStructureChange = true
            }
        }

        precondition(activeByKey.isEmpty, "active roots left after reconcile")

        leavingAnchors.sort { lhs, rhs in
            lhs.sourceIndex < rhs.sourceIndex
        }

        var leavingByOffset: [Int: [MountRoot]] = [:]
        leavingByOffset.reserveCapacity(leavingAnchors.count)
        for anchor in leavingAnchors {
            guard let root = leavingByKey[anchor.key] else { continue }
            let boundedOffset = min(anchor.anchorActiveOffset, targetActiveRoots.count)
            leavingByOffset[boundedOffset, default: []].append(root)
        }

        var rebuiltRoots: [MountRoot] = []
        rebuiltRoots.reserveCapacity(targetActiveRoots.count + leavingByKey.count)
        for activeIndex in 0...targetActiveRoots.count {
            if let leavingRoots = leavingByOffset[activeIndex] {
                rebuiltRoots.append(contentsOf: leavingRoots)
            }
            if activeIndex < targetActiveRoots.count {
                rebuiltRoots.append(targetActiveRoots[activeIndex])
            }
        }
        roots = rebuiltRoots

        var activeRootIndicesByKey: [_ViewKey: Int] = [:]
        activeRootIndicesByKey.reserveCapacity(newKeysArray.count)
        for index in roots.indices where roots[index].isActive {
            precondition(activeRootIndicesByKey[roots[index].key] == nil, "duplicate active key after rebuild")
            activeRootIndicesByKey[roots[index].key] = index
        }

        for (index, key) in newKeysArray.enumerated() {
            guard let rootIndex = activeRootIndicesByKey[key] else {
                preconditionFailure("missing active key after reconcile: \(key)")
            }
            if roots[rootIndex].isPending { continue }
            let patched = roots[rootIndex].patchMounted(as: Node.self) { node in
                patchNode(index, &node, &tx)
            }
            precondition(patched, "expected mounted child during keyed patch")
        }

        if didStructureChange, !didReportLayoutChange {
            reportLayoutChange(&tx)
        }
    }

    private func assertNoPendingRoots() {
        precondition(
            !roots.contains(where: \.isPending),
            "double patch of pending MountRoot in MountRootContainer"
        )
    }

    private func makeKeyIndexMap(_ keys: [_ViewKey]) -> [_ViewKey: Int] {
        var map: [_ViewKey: Int] = [:]
        map.reserveCapacity(keys.count)
        for (index, key) in keys.enumerated() {
            precondition(map[key] == nil, "duplicate key in patch: \(key)")
            map[key] = index
        }
        return map
    }

    private func makeMountRoot<Node: _Reconcilable>(
        key: _ViewKey,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) -> MountRoot {
        MountRoot(
            key: key,
            eager: viewContext,
            ctx: &ctx,
            create: { context, mountCtx in
                AnyReconcilable(makeNode(context, &mountCtx))
            }
        )
    }

    private func makePatchRoot<Node: _Reconcilable>(
        key: _ViewKey,
        transaction: Transaction,
        makeNode: @escaping (borrowing _ViewContext, inout _MountContext) -> Node
    ) -> MountRoot {
        MountRoot(
            key: key,
            pending: viewContext,
            transaction: transaction,
            create: { context, mountCtx in
                AnyReconcilable(makeNode(context, &mountCtx))
            }
        )
    }
}
