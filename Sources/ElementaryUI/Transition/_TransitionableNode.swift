import BasicContainers

public struct _TransitionableNode<Node: _Reconcilable & ~Copyable>:
    ~Copyable,
    _Reconcilable
{
    private enum Storage: ~Copyable {
        case direct(Node)
        case transitioned(_TransitionElement)
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
        guard let transition = context.transition else {
            storage = .direct(makeNode(context, &ctx))
            return
        }

        // An element consumes the transition modifier; it must never leak into
        // structural content mounted below that element.
        var nodeContext = copy context
        nodeContext.transition = nil

        // Without a structural owner there is nothing that can defer removal.
        guard ctx.slotTransitions != nil else {
            storage = .direct(makeNode(nodeContext, &ctx))
            return
        }

        let element = _TransitionElement(
            transition: transition.value,
            context: nodeContext,
            ctx: &ctx,
            makeElement: { context, ctx in
                AnyReconcilable(makeNode(context, &ctx))
            }
        )

        storage = .transitioned(element)
    }

    mutating func update(
        _ tx: inout _TransactionContext,
        body: (inout Node, inout _TransactionContext) -> Void
    ) {
        var storage = Storage._movedOut
        swap(&storage, &self.storage)

        switch consume storage {
        case .direct(var node):
            body(&node, &tx)
            self.storage = .direct(node)
        case .transitioned(let transitionedElement):
            transitionedElement.forEachPlaceholder { placeholder in
                placeholder.modify(as: Node.self) { node in
                    body(&node, &tx)
                }
            }
            self.storage = .transitioned(transitionedElement)
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
}

/// Owns a mounted transition body and every placeholder where that body mounts
/// its underlying element. Custom transition bodies may omit or duplicate it.
final class _TransitionElement {
    private let transition: AnyTransition
    private var bodyNode: AnyReconcilable?
    private var placeholderNode: AnyReconcilable?
    private var additionalPlaceholderNodes: UniqueArray<AnyReconcilable> = .init()
    private var makeElement:
        (
            (
                borrowing _ViewContext,
                inout _MountContext
            ) -> AnyReconcilable
        )?

    @inline(never)
    init(
        transition: AnyTransition,
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

        let initialPhase = transitionInitialPhase(
            defaultAnimation: transition.animation,
            transaction: ctx.transaction
        )
        self.bodyNode = transition.makeNode(
            phase: initialPhase,
            context: context,
            ctx: &ctx,
            makePlaceholderNode: self.makePlaceholderNode
        )
        ctx.registerTransition(self, initialPhase: initialPhase)
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
        transition.patchNode(
            to: phase,
            node: &bodyNode!,
            tx: &tx,
            makePlaceholderNode: self.makePlaceholderNode
        )
    }

    func forEachPlaceholder(_ body: (inout AnyReconcilable) -> Void) {
        guard placeholderNode != nil else { return }
        body(&placeholderNode!)

        for index in additionalPlaceholderNodes.indices {
            body(&additionalPlaceholderNodes[index])
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
    ) {
        if placeholderNode == nil {
            placeholderNode = makeElement!(context, &ctx)
        } else {
            additionalPlaceholderNodes.append(makeElement!(context, &ctx))
        }
    }
}
