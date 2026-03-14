final class MountRootContainer {
    var activeRoots: [MountRoot]
    private var leavingTracker: LeavingTracker
    var containerHandle: LayoutContainer.Handle?

    init(roots: [MountRoot]) {
        self.activeRoots = roots
        self.leavingTracker = LeavingTracker()
    }

    func collect(into ops: inout LayoutPass, context: inout _CommitContext) {
        if containerHandle == nil { containerHandle = ops.containerHandle }

        var lIndex = 0
        var nextInsertionPoint = leavingTracker.insertionIndex(for: 0)

        for cIndex in activeRoots.indices {
            if nextInsertionPoint == cIndex {
                let removed = leavingTracker.commitAndCheckRemoval(at: lIndex, ops: &ops, context: &context)
                if !removed { lIndex += 1 }
                nextInsertionPoint = leavingTracker.insertionIndex(for: lIndex)
            }
            activeRoots[cIndex].collect(into: &ops, &context)
        }

        while nextInsertionPoint != nil {
            let removed = leavingTracker.commitAndCheckRemoval(at: lIndex, ops: &ops, context: &context)
            if !removed { lIndex += 1 }
            nextInsertionPoint = leavingTracker.insertionIndex(for: lIndex)
        }
    }

    func unmount(_ context: inout _CommitContext) {
        for i in activeRoots.indices { activeRoots[i].unmount(&context) }
        for i in leavingTracker.entries.indices { leavingTracker.entries[i].value.unmount(&context) }
        activeRoots.removeAll()
        leavingTracker.entries.removeAll()
    }

    func reportLayoutChange(_ tx: inout _TransactionContext) {
        containerHandle?.reportLayoutChange(&tx)
    }

    var hasLeavingRoots: Bool {
        !leavingTracker.entries.isEmpty
    }

    func makeEagerRoot(
        context: borrowing _ViewContext,
        transaction: Transaction,
        ctx: inout _MountContext,
        create: (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) -> MountRoot {
        MountRoot(eager: context, transaction: transaction, ctx: &ctx, create: create)
    }

    private func addLeaving(_ root: MountRoot, atOriginalIndex: Int) {
        leavingTracker.insert(root, atOriginalIndex: atOriginalIndex)
    }

    /// Creates a pending `MountRoot` that captures tx animation hints for enter orchestration.
    func makePendingEnteringRoot(
        context: borrowing _ViewContext,
        transaction: Transaction,
        create: @escaping (borrowing _ViewContext, inout _MountContext) -> AnyReconcilable
    ) -> MountRoot {
        MountRoot(pending: context, transaction: transaction, create: create)
    }

    /// Removes an active root and tracks it in leaving order.
    func removeActiveRoot(
        at index: Int,
        originalIndex: Int? = nil,
        tx: inout _TransactionContext
    ) {
        let originalIndex = originalIndex ?? index
        reportLayoutChange(&tx)
        var root = activeRoots.remove(at: index)
        root.startRemoval(&tx, handle: containerHandle)
        addLeaving(root, atOriginalIndex: originalIndex)
    }

    /// Moves all active roots into leaving state and clears active roots.
    func removeAllActiveToLeaving(tx: inout _TransactionContext) {
        guard !activeRoots.isEmpty else { return }
        reportLayoutChange(&tx)
        for index in activeRoots.indices {
            var leaving = activeRoots[index]
            leaving.startRemoval(&tx, handle: containerHandle)
            addLeaving(leaving, atOriginalIndex: index)
        }
        activeRoots.removeAll()
    }

    /// Inserts an active root and updates leaving insertion offsets.
    func insertActiveRoot(_ root: MountRoot, at index: Int) {
        activeRoots.insert(root, at: index)
        leavingTracker.reflectInsertionAt(index)
    }

    /// Replaces an active root with an entering root while moving the previous active root to leaving state.
    func replaceActiveRoot(
        at activeIndex: Int,
        with enteringRoot: MountRoot,
        removedOriginalIndex: Int,
        tx: inout _TransactionContext
    ) {
        reportLayoutChange(&tx)
        var leaving = activeRoots[activeIndex]
        leaving.startRemoval(&tx, handle: containerHandle)
        addLeaving(leaving, atOriginalIndex: removedOriginalIndex)
        activeRoots[activeIndex] = enteringRoot
    }

    /// Restores a leaving root back to active and moves the current active root to leaving.
    func restoreLeavingRootToActive(
        leavingIndex: Int,
        activeIndex: Int,
        activeOriginalIndex: Int,
        tx: inout _TransactionContext
    ) {
        reportLayoutChange(&tx)
        var root = leavingTracker.entries.remove(at: leavingIndex).value
        root.cancelRemoval(&tx, handle: containerHandle)
        var leaving = activeRoots[activeIndex]
        leaving.startRemoval(&tx, handle: containerHandle)
        addLeaving(leaving, atOriginalIndex: activeOriginalIndex)
        activeRoots[activeIndex] = root
    }

    func hasPendingRoots() -> Bool {
        let hasPendingChildren = activeRoots.contains { $0.isPending }
        let hasPendingLeaving = leavingTracker.entries.contains { $0.value.isPending }
        return hasPendingChildren || hasPendingLeaving
    }
}

extension MountRootContainer {
    struct LeavingTracker {
        struct Entry {
            var originalMountIndex: Int
            var value: MountRoot
        }

        var entries: [Entry] = []

        func insertionIndex(for index: Int) -> Int? {
            guard index < entries.count else { return nil }
            return entries[index].originalMountIndex
        }

        mutating func insert(_ root: MountRoot, atOriginalIndex index: Int) {
            let newEntry = Entry(originalMountIndex: index, value: root)
            if let insertIndex = entries.firstIndex(where: { $0.originalMountIndex > index }) {
                entries.insert(newEntry, at: insertIndex)
            } else {
                entries.append(newEntry)
            }
        }

        mutating func reflectInsertionAt(_ index: Int) {
            shiftFromIndexUpwards(index, by: 1)
        }

        mutating func shiftFromIndexUpwards(_ index: Int, by amount: Int) {
            for i in entries.indices where entries[i].originalMountIndex >= index {
                entries[i].originalMountIndex += amount
            }
        }

        mutating func commitAndCheckRemoval(
            at index: Int,
            ops: inout LayoutPass,
            context: inout _CommitContext
        ) -> Bool {
            entries[index].value.collect(into: &ops, &context)
            guard entries[index].value.isFullyRemoved else { return false }
            var entry = entries.remove(at: index)
            shiftFromIndexUpwards(entry.originalMountIndex, by: -1)
            entry.value.unmount(&context)
            return true
        }
    }
}

final class LayoutContainer {
    let domNode: DOM.Node
    private let scheduler: Scheduler
    private var layoutObservers: [any DOMLayoutObserver]
    private var layoutNodes: [LayoutNode]
    private var isDirty: Bool = false

    init(
        domNode: DOM.Node,
        scheduler: Scheduler,
        layoutNodes: [LayoutNode],
        layoutObservers: [any DOMLayoutObserver]
    ) {
        self.domNode = domNode
        self.scheduler = scheduler
        self.layoutNodes = layoutNodes
        self.layoutObservers = layoutObservers
    }

    func mountInitial(_ context: inout _CommitContext) {
        var ops = LayoutPass(layoutContainer: self)
        collectLayout(&ops, &context)

        if ops.entries.count == 1 {
            context.dom.insertChild(ops.entries[0].reference, before: nil, in: domNode)
        } else if ops.entries.count > 1 {
            context.dom.replaceChildren(ops.entries.map { $0.reference }, in: domNode)
        }

        for observer in layoutObservers {
            observer.didLayoutChildren(parent: domNode, entries: ops.entries, context: &context)
        }
    }

    // TODO: I get rid of this...
    func removeAllChildren(_ context: inout _CommitContext) {
        var ops = LayoutPass(layoutContainer: self)
        collectLayout(&ops, &context)

        if ops.entries.count == 1 {
            context.dom.removeChild(ops.entries[0].reference, from: domNode)
        } else if ops.entries.count > 1 {
            context.dom.replaceChildren([], in: domNode)
        }
    }

    private func collectLayout(_ ops: inout LayoutPass, _ context: inout _CommitContext) {
        for node in layoutNodes {
            node.collect(into: &ops, context: &context)
        }
    }

    private func markDirty(_ tx: inout _TransactionContext) {
        guard !isDirty else { return }

        isDirty = true
        tx.scheduler.addPlacementAction(performLayout(_:))
        for observer in layoutObservers {
            observer.willLayoutChildren(parent: domNode, context: &tx)
        }
    }

    private func reportLeavingElement(_ node: DOM.Node, _ tx: inout _TransactionContext) {
        for observer in layoutObservers {
            observer.setLeaveStatus(node, isLeaving: true, context: &tx)
        }
    }

    private func reportReenteringElement(_ node: DOM.Node, _ tx: inout _TransactionContext) {
        for observer in layoutObservers {
            observer.setLeaveStatus(node, isLeaving: false, context: &tx)
        }
    }

    private func performLayout(_ context: inout _CommitContext) {
        guard isDirty else { return }
        isDirty = false

        var ops = LayoutPass(layoutContainer: self)
        collectLayout(&ops, &context)

        if ops.canBatchReplace {
            if ops.isAllRemovals {
                context.dom.replaceChildren([], in: domNode)
            } else if ops.isAllAdditions {
                context.dom.replaceChildren(ops.entries.map { $0.reference }, in: domNode)
            } else {
                fatalError("invalid batch replace pass in layout container")
            }
        } else {
            var sibling: DOM.Node?
            for entry in ops.entries.reversed() {
                switch entry.kind {
                case .added, .moved:
                    context.dom.insertChild(entry.reference, before: sibling, in: domNode)
                    sibling = entry.reference
                case .removed:
                    context.dom.removeChild(entry.reference, from: domNode)
                case .unchanged:
                    sibling = entry.reference
                }
            }
        }

        for observer in layoutObservers {
            observer.didLayoutChildren(parent: domNode, entries: ops.entries, context: &context)
        }
    }

    struct Handle {
        private let container: LayoutContainer

        init(container: LayoutContainer) {
            self.container = container
        }

        func reportLayoutChange(_ tx: inout _TransactionContext) {
            container.markDirty(&tx)
        }

        func reportLeavingElement(_ node: DOM.Node, _ tx: inout _TransactionContext) {
            container.reportLeavingElement(node, &tx)
        }

        func reportReenteringElement(_ node: DOM.Node, _ tx: inout _TransactionContext) {
            container.reportReenteringElement(node, &tx)
        }
    }
}

enum LayoutNode {
    case elementNode(DOM.Node)
    case textNode(DOM.Node)
    case container(MountRootContainer)

    func collect(into ops: inout LayoutPass, context: inout _CommitContext) {
        switch self {
        case .elementNode(let node):
            ops.append(.init(kind: .unchanged, reference: node, type: .element))
        case .textNode(let node):
            ops.append(.init(kind: .unchanged, reference: node, type: .text))
        case .container(let container):
            container.collect(into: &ops, context: &context)
        }
    }

    var isStatic: Bool {
        switch self {
        case .elementNode, .textNode:
            true
        case .container:
            false
        }
    }
}

struct LayoutPass: ~Copyable {
    var entries: [Entry]
    var containerHandle: LayoutContainer.Handle

    private(set) var isAllRemovals: Bool = true
    private(set) var isAllAdditions: Bool = true

    var canBatchReplace: Bool {
        (isAllRemovals || isAllAdditions) && entries.count > 1
    }

    init(layoutContainer: LayoutContainer) {
        entries = []
        self.containerHandle = .init(container: layoutContainer)
    }

    mutating func append(_ entry: Entry) {
        entries.append(entry)
        isAllAdditions = isAllAdditions && entry.kind == .added
        isAllRemovals = isAllRemovals && entry.kind == .removed
    }

    mutating func recomputeBatchFlags() {
        isAllAdditions = true
        isAllRemovals = true
        for entry in entries {
            isAllAdditions = isAllAdditions && entry.kind == .added
            isAllRemovals = isAllRemovals && entry.kind == .removed
        }
    }

    struct Entry {
        enum NodeType {
            case element
            case text
        }

        enum Status {
            case unchanged
            case added
            case removed
            case moved
        }

        let kind: Status
        let reference: DOM.Node
        let type: NodeType
    }
}
