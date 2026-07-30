import BasicContainers

/// Owns the keyed child slots of one structural view (conditional content,
/// keyed lists, ...).
///
/// A slot moves through three lanes:
///
/// ```
/// active ──key dropped──▶ removed ──exit transition starts──▶ leaving
///    ▲                      │  ▲                                 │
///    │                      │  └─────transitions finished────────┤
///    │                   collect                                 │
///    │            (.removed ops, unmount)                        │
///    └───────────────────key reappears (revive)──────────────────┘
/// ```
///
/// - `activeSlots`: mounted and part of layout, ordered by the current keys.
/// - `leavingSlots`: dropped from active while an exit transition runs; their
///   DOM stays in place and they can be revived by key.
/// - `removedSlots`: done; the next `collect` emits their `.removed` layout
///   ops and unmounts them.
final class MountContainer {
    private let viewContext: _ViewContext
    private var activeSlots: UniqueArray<Slot>
    private var leavingSlots: UniqueArray<Slot> = .init()
    private var removedSlots: UniqueArray<Slot> = .init()

    var containerHandle: LayoutContainer.Handle?

    private init(context: borrowing _ViewContext, slots: consuming UniqueArray<Slot>) {
        self.viewContext = copy context
        self.activeSlots = slots
    }

    convenience init<Node: _Reconcilable & ~Copyable>(
        mountedKey key: _ViewKey,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.init(
            mountedKeyStorage: CollectionOfOne(key).span,
            context: context,
            ctx: &ctx,
            makeNode: { _, context, ctx in makeNode(context, &ctx) }
        )
    }

    convenience init<Node: _Reconcilable & ~Copyable>(
        mountedKeyStorage keys: borrowing Span<_ViewKey>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> Node
    ) {
        self.init(
            context: context,
            slots: UniqueArray<Slot>(capacity: keys.count) { span in
                for index in keys.indices {
                    span.append(
                        ctx.mountSlot(
                            key: keys[unchecked: index],
                            newKeyIndex: index,
                            env: context,
                            makeNode: { index, context, ctx in
                                AnyReconcilable(makeNode(index, context, &ctx))
                            }
                        )
                    )
                }
            }
        )
    }

    func collect(into ops: inout LayoutPass, context: inout _CommitContext, op: LayoutPass.Entry.LayoutOp) {
        if containerHandle == nil { containerHandle = ops.containerHandle }

        promoteCompletedLeavingSlots()

        while let removed = removedSlots.popLast() {
            removed.collectRemoved(into: &ops, context: &context)
        }

        for index in activeSlots.indices {
            activeSlots[index].collectActive(
                into: &ops,
                context: &context,
                parentOp: op
            )
        }
    }

    func unmount(_ context: inout _CommitContext) {
        for index in activeSlots.indices {
            activeSlots[index].unmount(&context)
        }
        for index in leavingSlots.indices {
            leavingSlots[index].unmount(&context)
        }
        while var removed = removedSlots.popLast() {
            removed.unmount(&context)
        }

        activeSlots.removeAll()
        leavingSlots.removeAll()
        containerHandle = nil
    }

    func reportLayoutChange(_ tx: inout _TransactionContext) {
        containerHandle?.reportLayoutChange(&tx)
    }

    func patch(
        key newKey: _ViewKey,
        tx: inout _TransactionContext,
        makeNode: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (inout AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        patch(
            keys: CollectionOfOne(newKey).span,
            tx: &tx,
            makeNode: { _, context, ctx in makeNode(context, &ctx) },
            patchNode: { _, node, tx in patchNode(&node, &tx) }
        )
    }

    func patch(
        keys newKeys: borrowing Span<_ViewKey>,
        tx: inout _TransactionContext,
        makeNode: (Int, borrowing _ViewContext, inout _MountContext) -> AnyReconcilable,
        patchNode: (Int, inout AnyReconcilable, inout _TransactionContext) -> Void
    ) {
        activeSlots.reserveCapacity(newKeys.count)

        let firstDroppedIndex = removedSlots.count

        let didStructureChange = tx.scheduler.scratch.withDiffEngine { differ in
            differ.run(
                activeSlots: &activeSlots,
                leavingSlots: &leavingSlots,
                removedSlots: &removedSlots,
                keys: newKeys,
                makeNewSlot: { [viewContext] newKeyIndex, key in
                    var slot = tx.scheduler.withMountContext(tx: &tx) { (ctx: consuming _MountContext) in
                        var ctx = ctx
                        return ctx.mountSlot(
                            key: key,
                            newKeyIndex: newKeyIndex,
                            env: viewContext,
                            makeNode: makeNode
                        )
                    }
                    slot.placement = .added
                    return slot
                }
            )
        }

        // The diff dropped slots straight into the removed lane. Those that
        // start an exit transition move to the leaving lane instead.
        var index = firstDroppedIndex
        while index < removedSlots.count {
            if removedSlots[index].deferRemovalIfNeeded(tx: &tx, handle: containerHandle) {
                leavingSlots.append(removedSlots.remove(at: index))
            } else {
                index += 1
            }
        }

        for index in activeSlots.indices {
            activeSlots[index].patch(
                newKeyIndex: index,
                tx: &tx,
                patchNode: patchNode
            )
        }

        if didStructureChange {
            containerHandle?.reportLayoutChange(&tx)
        }
    }

    /// Moves leaving slots whose exit transitions have finished into the
    /// removed lane.
    private func promoteCompletedLeavingSlots() {
        var index = 0
        while index < leavingSlots.count {
            if leavingSlots[index].isRemovalComplete {
                removedSlots.append(leavingSlots.remove(at: index))
            } else {
                index += 1
            }
        }
    }
}

extension MountContainer {
    /// Visits every slot that is still mounted (active and leaving lanes).
    func forEachLiveSlot(
        _ body: (borrowing Slot) -> Void
    ) {
        for index in activeSlots.indices {
            body(activeSlots[index])
        }
        for index in leavingSlots.indices {
            body(leavingSlots[index])
        }
    }
}

extension MountContainer {
    /// One keyed child: its mounted node, the layout nodes it produced, and
    /// the transition state that decides how it enters and leaves.
    struct Slot: ~Copyable {
        enum Placement {
            case unchanged
            case added
            case moved
        }

        let key: _ViewKey
        var node: AnyReconcilable
        var layoutNodes: RigidArray<LayoutNode>
        var placement: Placement
        var transitions: _SlotTransitions
        var pendingRemoval: _PendingRemoval?

        init(
            key: _ViewKey,
            node: consuming AnyReconcilable,
            layoutNodes: consuming RigidArray<LayoutNode>,
            transitions: consuming _SlotTransitions
        ) {
            self.key = key
            self.node = node
            self.layoutNodes = layoutNodes
            self.placement = .unchanged
            self.transitions = transitions
            self.pendingRemoval = nil
        }

        var isRemovalComplete: Bool {
            pendingRemoval?.isComplete == true
        }

        mutating func patch(
            newKeyIndex: Int,
            tx: inout _TransactionContext,
            patchNode: (Int, inout AnyReconcilable, inout _TransactionContext) -> Void
        ) {
            if let removal = pendingRemoval {
                // revived from the leaving lane: abort the exit transition
                removal.cancel(tx: &tx)
                pendingRemoval = nil
                placement = .moved
            }

            patchNode(newKeyIndex, &node, &tx)
        }

        mutating func markMoved() {
            if placement == .unchanged {
                placement = .moved
            }
        }

        /// Starts exit transitions for a slot that just left the active lane.
        /// Returns true if the removal is deferred: the slot must park in the
        /// leaving lane until its transitions finish.
        ///
        /// Slots added and dropped within the same patch never entered layout,
        /// so they skip transitions (and their `.added` placement makes
        /// `collectRemoved` skip the layout ops too).
        mutating func deferRemovalIfNeeded(
            tx: inout _TransactionContext,
            handle: LayoutContainer.Handle?
        ) -> Bool {
            guard placement != .added,
                let removal = _PendingRemoval.begin(
                    for: self,
                    handle: handle,
                    tx: &tx
                )
            else {
                return false
            }
            pendingRemoval = removal
            return true
        }

        mutating func collectActive(
            into ops: inout LayoutPass,
            context: inout _CommitContext,
            parentOp: LayoutPass.Entry.LayoutOp
        ) {
            let childOp: LayoutPass.Entry.LayoutOp
            switch placement {
            case .unchanged:
                childOp = parentOp
            case .added:
                childOp = .added
            case .moved:
                childOp = .moved
            }
            layoutNodes.collect(into: &ops, context: &context, op: childOp)
            placement = .unchanged
        }

        /// Emits the `.removed` layout ops (unless the slot never entered
        /// layout) and unmounts. Terminal: consumes the slot.
        consuming func collectRemoved(into ops: inout LayoutPass, context: inout _CommitContext) {
            if placement != .added {
                layoutNodes.collect(into: &ops, context: &context, op: .removed)
            }
            node.unmount(&context)
        }

        mutating func unmount(_ context: inout _CommitContext) {
            node.unmount(&context)
        }
    }
}
