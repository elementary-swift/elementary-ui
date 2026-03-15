public final class _TransitionNode<T: Transition, V: View>: _Reconcilable {
    private var value: _TransitionView<T, V>
    // NOTE: stored as AnyReconcilable (not T.Body._MountedNode?) to avoid
    // keeping a potentially struct-typed optional inline in this class, which
    // causes an Embedded Swift IR field-offset assertion failure.
    private var node: AnyReconcilable?

    private var placeholderView: PlaceholderContentView<T>?
    private var placeholderNode: _PlaceholderNode?
    // a transition can theoretically duplicate the content node, but it will be rare
    private var additionalPlaceholderNodes: [_PlaceholderNode] = []

    init(view: consuming _TransitionView<T, V>, context: borrowing _ViewContext, ctx: inout _MountContext) {
        let view = view
        self.value = view
        self.placeholderView = PlaceholderContentView<T>(makeNodeFn: self.makePlaceholderNode)

        let initialPhase = ctx.appendTransitionParticipant(self)
        self.node = ctx.withTransitionBoundary { childCtx in
            makeInitialNode(for: initialPhase, context: context, ctx: &childCtx)
        }
    }

    func patchWrappedContent(_ view: consuming _TransitionView<T, V>, tx: inout _TransactionContext) {
        self.value = view

        if let placeholderNode {
            placeholderNode.node.modify(as: V._MountedNode.self) { node in
                V._patchNode(self.value.wrapped, node: &node, tx: &tx)
            }
        }

        for placeholder in additionalPlaceholderNodes {
            placeholder.node.modify(as: V._MountedNode.self) { node in
                V._patchNode(self.value.wrapped, node: &node, tx: &tx)
            }
        }
    }

    func patchTransitionPhase(_ phase: TransitionPhase, tx: inout _TransactionContext) {
        guard let placeholderView else { return }
        node?.modify(as: T.Body._MountedNode.self) { node in
            T.Body._patchNode(
                value.transition.body(content: placeholderView, phase: phase),
                node: &node,
                tx: &tx
            )
        }
    }

    func makeInitialNode(
        for phase: TransitionPhase,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> AnyReconcilable {
        AnyReconcilable(
            T.Body._makeNode(
                value.transition.body(content: placeholderView!, phase: phase),
                context: context,
                ctx: &ctx
            )
        )
    }

    private func makePlaceholderNode(context: borrowing _ViewContext, ctx: inout _MountContext) -> _PlaceholderNode {
        let node = _PlaceholderNode(node: AnyReconcilable(V._makeNode(value.wrapped, context: context, ctx: &ctx)))
        if placeholderNode == nil {
            placeholderNode = node
        } else {
            additionalPlaceholderNodes.append(node)
        }
        return node
    }

    public func unmount(_ context: inout _CommitContext) {
        node?.unmount(&context)

        node = nil
        placeholderNode = nil
        additionalPlaceholderNodes.removeAll()
    }
}

extension _TransitionNode: MountRootTransitionParticipant {
    var mountRootDefaultAnimation: Animation? {
        value.animation
    }

    var mountRootIsMounted: Bool {
        node != nil
    }

    func mountRootPatchTransitionPhase(_ phase: TransitionPhase, tx: inout _TransactionContext) {
        patchTransitionPhase(phase, tx: &tx)
    }
}
