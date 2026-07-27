// TODO-TRANSITION: simplify this, AI is too stupid

public struct _TransitionableNode<Node: _Reconcilable & ~Copyable>:
    ~Copyable,
    _Reconcilable
{
    private enum Storage: ~Copyable {
        case direct(Node)
        case transitioned(_TransitionedElement)
        case _movedOut
    }

    private var storage: Storage

    init(
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeNode:
            @escaping (
                borrowing _ViewContext,
                inout _MountContext
            ) -> Node
    ) {
        guard let transition = context.transition, ctx.mountRoot != nil else {
            storage = .direct(makeNode(context, &ctx))
            return
        }

        var nodeContext = copy context
        nodeContext.transition = nil

        let initialPhase = transitionInitialPhase(
            defaultAnimation: transition.animation,
            transaction: ctx.transaction
        )
        let transitionedElement = _TransitionedElement(
            transition: transition,
            initialPhase: initialPhase,
            context: nodeContext,
            ctx: &ctx,
            makeElement: { context, ctx in
                AnyReconcilable(makeNode(context, &ctx))
            }
        )
        ctx.registerTransition(
            transitionedElement,
            initialPhase: initialPhase
        )
        storage = .transitioned(transitionedElement)
    }

    mutating func update(
        _ tx: inout _TransactionContext,
        body: (inout Node, inout _TransactionContext) -> Void
    ) {
        let storage = takeStorage()

        switch consume storage {
        case .direct(var node):
            body(&node, &tx)
            putStorage(.direct(node))
        case .transitioned(let transitionedElement):
            transitionedElement.forEachPlaceholder { placeholder in
                placeholder.node.modify(as: Node.self) { node in
                    body(&node, &tx)
                }
            }
            putStorage(.transitioned(transitionedElement))
        case ._movedOut:
            preconditionFailure(
                "_TransitionableNode storage was already moved out"
            )
        }
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        switch consume storage {
        case .direct(let node):
            node.unmount(&context)
        case .transitioned(let transitionedElement):
            transitionedElement.unmount(&context)
        case ._movedOut:
            preconditionFailure(
                "_TransitionableNode storage was already moved out"
            )
        }
    }

    @inline(__always)
    private mutating func takeStorage() -> Storage {
        var storage = Storage._movedOut
        swap(&storage, &self.storage)
        return storage
    }

    @inline(__always)
    private mutating func putStorage(_ storage: consuming Storage) {
        self.storage = storage
    }
}

final class _TransitionedElement {
    private let transition: _AnyTransition
    private var bodyNode: AnyReconcilable?
    private var placeholderNode: _PlaceholderNode?
    private var additionalPlaceholderNodes: [_PlaceholderNode] = []
    private var makeElement:
        (
            (
                borrowing _ViewContext,
                inout _MountContext
            ) -> AnyReconcilable
        )?

    init(
        transition: _AnyTransition,
        initialPhase: TransitionPhase,
        context: borrowing _ViewContext,
        ctx: inout _MountContext,
        makeElement:
            @escaping (
                borrowing _ViewContext,
                inout _MountContext
            ) -> AnyReconcilable
    ) {
        self.transition = transition
        self.makeElement = makeElement
        self.bodyNode = transition.makeNode(
            phase: initialPhase,
            context: context,
            ctx: &ctx,
            makePlaceholderNode: self.makePlaceholderNode
        )
    }

    var defaultAnimation: Animation? {
        transition.animation
    }

    var isMounted: Bool {
        bodyNode != nil
    }

    func patchPhase(
        _ phase: TransitionPhase,
        tx: inout _TransactionContext
    ) {
        guard bodyNode != nil else { return }
        transition.patchPhase(
            phase,
            node: &bodyNode!,
            tx: &tx,
            makePlaceholderNode: self.makePlaceholderNode
        )
    }

    func forEachPlaceholder(_ body: (_PlaceholderNode) -> Void) {
        if let placeholderNode {
            body(placeholderNode)
        }
        for placeholder in additionalPlaceholderNodes {
            body(placeholder)
        }
    }

    func unmount(_ context: inout _CommitContext) {
        bodyNode?.unmount(&context)
        bodyNode = nil
        placeholderNode = nil
        additionalPlaceholderNodes.removeAll()
        makeElement = nil
    }

    private func makePlaceholderNode(
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _PlaceholderNode {
        var elementContext = copy context
        elementContext.transition = nil
        let node = _PlaceholderNode(
            node: makeElement!(elementContext, &ctx)
        )
        if placeholderNode == nil {
            placeholderNode = node
        } else {
            additionalPlaceholderNodes.append(node)
        }
        return node
    }
}
