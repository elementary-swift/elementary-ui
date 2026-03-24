final class LayoutContainer {
    let domNode: DOM.Node
    private let scheduler: Scheduler
    private let layoutNodes: [LayoutNode]
    private var layoutObservers: [any DOMLayoutObserver]
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
        layoutNodes.collect(into: &ops, context: &context, op: .added)

        if ops.entries.count == 1 {
            context.dom.appendChild(ops.entries[0].reference, to: domNode)
        } else if ops.entries.count > 1 {
            for entry in ops.entries {
                context.dom.appendChild(entry.reference, to: domNode)
            }
        }

        for observer in layoutObservers {
            observer.didLayoutChildren(parent: domNode, entries: ops.entries, context: &context)
        }
    }

    // TODO: I get rid of this...
    func removeAllChildren(_ context: inout _CommitContext) {
        var ops = LayoutPass(layoutContainer: self)
        layoutNodes.collect(into: &ops, context: &context, op: .removed)

        if ops.entries.count == 1 {
            context.dom.removeChild(ops.entries[0].reference, from: domNode)
        } else if ops.entries.count > 1 {
            context.dom.clearChildren(in: domNode)
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

        // TODO: use lifetimes and scratch container here
        var ops = LayoutPass(layoutContainer: self)
        layoutNodes.collect(into: &ops, context: &context, op: .unchanged)

        if ops.canBatchReplace {
            if ops.isAllRemovals {
                context.dom.clearChildren(in: domNode)
            } else if ops.isAllAdditions {
                for entry in ops.entries {
                    context.dom.appendChild(entry.reference, to: domNode)
                }
            } else {
                fatalError("invalid batch replace pass in layout container")
            }
        } else {
            var sibling: DOM.Node?
            for entry in ops.entries.reversed() {
                switch entry.op {
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
    case container(MountContainer)

    func collect(
        into ops: inout LayoutPass,
        context: inout _CommitContext,
        op: LayoutPass.Entry.LayoutOp
    ) {
        switch self {
        case .elementNode(let node):
            ops.append(.init(op: op, reference: node, type: .element))
        case .textNode(let node):
            ops.append(.init(op: op, reference: node, type: .text))
        case .container(let container):
            container.collect(into: &ops, context: &context, op: op)
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
        isAllAdditions = isAllAdditions && entry.op == .added
        isAllRemovals = isAllRemovals && entry.op == .removed
    }

    struct Entry {
        enum NodeType {
            case element
            case text
        }

        enum LayoutOp {
            case unchanged
            case added
            case removed
            case moved
        }

        let op: LayoutOp
        let reference: DOM.Node
        let type: NodeType
    }
}

extension [LayoutNode] {
    func collect(
        into ops: inout LayoutPass,
        context: inout _CommitContext,
        op: LayoutPass.Entry.LayoutOp
    ) {
        for node in self {
            node.collect(into: &ops, context: &context, op: op)
        }
    }
}
