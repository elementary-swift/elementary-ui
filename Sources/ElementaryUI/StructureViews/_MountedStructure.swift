final class MountRootContainer {
    var activeRoots: [MountRoot]
    var leavingTracker: LeavingTracker
    var containerHandle: LayoutContainer.Handle?

    init(roots: [MountRoot]) {
        self.activeRoots = roots
        self.leavingTracker = LeavingTracker()
    }

    func register(into ctx: inout _MountContext) {
        ctx.appendContainer(self)
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
        for root in activeRoots { root.unmount(&context) }
        for entry in leavingTracker.entries { entry.value.unmount(&context) }
        activeRoots.removeAll()
        leavingTracker.entries.removeAll()
    }

    func reportLayoutChange(_ tx: inout _TransactionContext) {
        containerHandle?.reportLayoutChange(&tx)
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
            let isRemovalCommitted = ops.withRemovalTracking { ops in
                entries[index].value.collect(into: &ops, &context)
            }

            if isRemovalCommitted {
                let entry = entries.remove(at: index)
                shiftFromIndexUpwards(entry.originalMountIndex, by: -1)
                entry.value.unmount(&context)
                return true
            } else {
                return false
            }
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

    mutating func withRemovalTracking(_ block: (inout Self) -> Void) -> Bool {
        let index = entries.count
        block(&self)
        var isRemoved = true
        for entry in entries[index..<entries.count] where entry.kind != .removed {
            isRemoved = false
            break
        }
        return isRemoved
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
