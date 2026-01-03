public final class _ElementNode: _Reconcilable {
    var identifier: String = ""
    var child: AnyReconcilable!

    var domNode: ManagedDOMReference?
    var mountedModifieres: [AnyUnmountable]?
    var layoutObservers: [any DOMLayoutObserver] = []

    var childrenLayoutStatus: ChildrenLayoutStatus = .init()

    struct ChildrenLayoutStatus {
        var isDirty = false
        var count: Int = 0
    }

    private(set) var parentNode: _ElementNode?

    init(
        tag: String,
        viewContext: borrowing _ViewContext,
        context: inout _TransactionContext,
        makeChild: (borrowing _ViewContext, inout _TransactionContext) -> AnyReconcilable
    ) {
        precondition(viewContext.parentElement != nil, "parent element must be set")
        self.parentNode = viewContext.parentElement
        self.identifier = "\(tag):\(ObjectIdentifier(self))"

        logTrace("created element \(identifier) in \(viewContext.parentElement!.identifier)")
        viewContext.parentElement!.reportChangedChildren(.elementAdded, context: &context)

        var viewContext = copy viewContext
        viewContext.parentElement = self
        let modifiers = viewContext.modifiers.take()
        self.layoutObservers = viewContext.layoutObservers.take()

        context.scheduler.addCommitAction(
            CommitAction { [self] context in
                precondition(self.domNode == nil, "element already has a DOM node")
                let ref = context.dom.createElement(tag)
                self.domNode = ManagedDOMReference(reference: ref, status: .added)

                self.mountedModifieres = modifiers.map {
                    $0.mount(ref, &context)
                }
            }
        )

        self.child = makeChild(viewContext, &context)
    }

    init(
        root: DOM.Node,
        viewContext: consuming _ViewContext,
        context: inout _TransactionContext,
        makeChild: (borrowing _ViewContext, inout _TransactionContext) -> AnyReconcilable
    ) {
        self.domNode = .init(reference: root, status: .unchanged)
        self.identifier = "\("_root_"):\(ObjectIdentifier(self))"

        var viewContext = viewContext
        let layoutObservers = viewContext.layoutObservers.take()
        viewContext.parentElement = self

        if !layoutObservers.isEmpty {
            self.layoutObservers = layoutObservers
        }

        self.child = makeChild(viewContext, &context)
    }

    func updateChild<Node: _Reconcilable>(
        _ context: inout _TransactionContext,
        as: Node.Type = Node.self,
        block: (_ node: Node, _ context: inout _TransactionContext) -> Void
    ) {
        block(self.child.unwrap(), &context)
    }

    func reportChangedChildren(_ change: ElementNodeChildrenChange, context: inout _TransactionContext) {
        // TODO: count needed storage for children
        // TODO: optimize for changes that do not require children re-run (leaving and re-entering nodes)

        if !childrenLayoutStatus.isDirty {
            childrenLayoutStatus.isDirty = true
            context.scheduler.addPlacementAction(CommitAction(run: performLayout(_:)))

            if let ref = domNode?.reference {
                for observer in layoutObservers {
                    observer.willLayoutChildren(parent: ref, context: &context)
                }
            }
        }

        switch change {
        case let .elementLeaving(node):
            for observer in layoutObservers {
                observer.setLeaveStatus(node, isLeaving: true, context: &context)
            }
        case let .elementReentered(node):
            for observer in layoutObservers {
                observer.setLeaveStatus(node, isLeaving: false, context: &context)
            }
        default:
            break
        }
    }

    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        assert(domNode != nil, "unitialized element in layout pass")
        self.domNode?.collectLayoutChanges(&ops, type: .element)
    }

    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        switch op {
        case .startRemoval:
            assert(domNode != nil, "unitialized element in startRemoval")
            domNode?.status = .removed
            parentNode?.reportChangedChildren(.elementRemoved, context: &tx)
        case .cancelRemoval:
            if domNode?.status == .removed {
                domNode?.status = .moved
                parentNode?.reportChangedChildren(.elementAdded, context: &tx)
            } else {
                guard let node = domNode?.reference else {
                    assertionFailure("unitialized element in cancelRemoval")
                    return
                }
                parentNode?.reportChangedChildren(.elementReentered(node), context: &tx)
            }
        case .markAsMoved:
            assert(domNode != nil, "unitialized element in markAsMoved")
            domNode?.status = .moved
            parentNode?.reportChangedChildren(.elementMoved, context: &tx)
        case .markAsLeaving:
            guard let node = domNode?.reference else {
                assertionFailure("unitialized element in markAsLeaving")
                return
            }
            parentNode?.reportChangedChildren(.elementLeaving(node), context: &tx)
        }
    }

    public func unmount(_ context: inout _CommitContext) {
        let c = self.child.take()!
        c.unmount(&context)

        for modifier in mountedModifieres ?? [] {
            modifier.unmount(&context)
        }
        self.mountedModifieres = nil

        for observer in layoutObservers {
            observer.unmount(&context)
        }
        self.layoutObservers = []

        self.domNode = nil
        self.parentNode = nil
    }

    func performLayout(_ context: inout _CommitContext) {
        guard let ref = domNode?.reference else {
            preconditionFailure("unitialized element in commitChanges - maybe this can be fine?")
        }

        guard childrenLayoutStatus.isDirty else {
            assertionFailure("layout triggered on non-dirty node")
            return
        }
        childrenLayoutStatus.isDirty = false

        var ops = _ContainerLayoutPass()  // TODO: initialize with count, could be allocationlessly somehow
        child!.collectChildren(&ops, &context)

        if ops.canBatchReplace {
            if ops.isAllRemovals {
                context.dom.replaceChildren([], in: ref)
            } else if ops.isAllAdditions {
                context.dom.replaceChildren(ops.entries.map { $0.reference }, in: ref)
            } else {
                fatalError("cannot batch replace children of \(ref) because it is not all removals or all additions")
            }
        } else {
            var sibling: DOM.Node?

            for entry in ops.entries.reversed() {
                switch entry.kind {
                case .added, .moved:
                    context.dom.insertChild(entry.reference, before: sibling, in: ref)
                    sibling = entry.reference
                case .removed:
                    context.dom.removeChild(entry.reference, from: ref)
                case .unchanged:
                    sibling = entry.reference
                    break
                }
            }
        }

        for observer in layoutObservers {
            observer.didLayoutChildren(parent: ref, entries: ops.entries, context: &context)
        }
    }
}

enum ElementNodeChildrenChange {
    case elementAdded
    case elementMoved
    case elementRemoved
    case elementLeaving(DOM.Node)
    case elementReentered(DOM.Node)

    var requiresChildrenUpdate: Bool {
        switch self {
        case .elementAdded, .elementMoved, .elementRemoved:
            true
        case .elementLeaving, .elementReentered:
            false
        }
    }
}

struct ManagedDOMReference: ~Copyable {
    let reference: DOM.Node
    var status: _ContainerLayoutPass.Entry.Status
}

extension ManagedDOMReference {
    mutating func collectLayoutChanges(_ ops: inout _ContainerLayoutPass, type: _ContainerLayoutPass.Entry.NodeType) {
        ops.append(.init(kind: status, reference: reference, type: type))
        self.status = .unchanged
    }
}
