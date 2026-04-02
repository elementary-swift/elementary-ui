import BasicContainers
import ContainersPreview

final class LayoutContainer {
    let domNode: DOM.Node
    private let layoutNodes: RigidArray<LayoutNode>
    private let layoutObservers: [any DOMLayoutObserver]
    private var isDirty: Bool = false

    init(
        domNode: DOM.Node,
        scheduler: Scheduler,
        layoutNodes: consuming RigidArray<LayoutNode>,
        layoutObservers: [any DOMLayoutObserver]
    ) {
        self.domNode = domNode
        self.layoutNodes = consume layoutNodes
        self.layoutObservers = layoutObservers
    }

    func mountInitial(_ context: inout _CommitContext) {
        context.scheduler.scratch.withLayoutEntryScratchFrame { scratch in
            var ops = LayoutPass(layoutContainer: self, scratch: consume scratch)
            layoutNodes.collect(into: &ops, context: &context, op: .added)

            ops.consume { entries in
                for index in entries.indices {
                    context.dom.appendChild(entries[unchecked: index].reference, to: domNode)
                }
                for observer in layoutObservers {
                    observer.didLayoutChildren(parent: domNode, entries: entries.span, context: &context)
                }
            }
        }
    }

    // TODO: I get rid of this...
    func removeAllChildren(_ context: inout _CommitContext) {
        context.scheduler.scratch.withLayoutEntryScratchFrame { scratch in
            var ops = LayoutPass(layoutContainer: self, scratch: consume scratch)
            layoutNodes.collect(into: &ops, context: &context, op: .removed)
            let entryCount = ops.count

            ops.consume { entries in
                if entryCount == 1 {
                    context.dom.removeChild(entries[unchecked: 0].reference, from: domNode)
                } else if entryCount > 1 {
                    context.dom.clearChildren(in: domNode)
                }
            }
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

        context.scheduler.scratch.withLayoutEntryScratchFrame { scratch in
            var ops = LayoutPass(layoutContainer: self, scratch: consume scratch)
            layoutNodes.collect(into: &ops, context: &context, op: .unchanged)
            let canBatchReplace = ops.canBatchReplace
            let isAllRemovals = ops.isAllRemovals
            let isAllAdditions = ops.isAllAdditions

            ops.consume { entries in
                if canBatchReplace {
                    if isAllRemovals {
                        context.dom.clearChildren(in: domNode)
                    } else if isAllAdditions {
                        for index in entries.indices {
                            context.dom.appendChild(entries[unchecked: index].reference, to: domNode)
                        }
                    } else {
                        fatalError("invalid batch replace pass in layout container")
                    }
                } else {
                    var sibling: DOM.Node?
                    var index = entries.count
                    while index > 0 {
                        index -= 1
                        let entry = entries[unchecked: index]
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
                    observer.didLayoutChildren(parent: domNode, entries: entries.span, context: &context)
                }
            }
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

struct LayoutPass: ~Copyable, ~Escapable {
    private var entryScratch: ScratchStack<Entry>
    var containerHandle: LayoutContainer.Handle

    private(set) var isAllRemovals: Bool = true
    private(set) var isAllAdditions: Bool = true

    var canBatchReplace: Bool {
        (isAllRemovals || isAllAdditions) && count > 1
    }

    @_lifetime(copy scratch)
    fileprivate init(layoutContainer: LayoutContainer, scratch: consuming ScratchStack<Entry>) {
        self.entryScratch = consume scratch
        self.containerHandle = .init(container: layoutContainer)
    }

    var count: Int {
        entryScratch.count
    }

    consuming func consume(_ body: (inout InputSpan<Entry>) -> Void) {
        entryScratch.consume(body)
    }

    mutating func append(_ entry: Entry) {
        entryScratch.append(entry)
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

extension RigidArray where Element == LayoutNode {
    borrowing func collect(
        into ops: inout LayoutPass,
        context: inout _CommitContext,
        op: LayoutPass.Entry.LayoutOp
    ) {
        let nodes = span
        for index in nodes.indices {
            nodes[unchecked: index].collect(into: &ops, context: &context, op: op)
        }
    }
}
