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
        let defaultAnimation = view.animation
        self.value = view
        self.placeholderView = PlaceholderContentView<T>(makeNodeFn: self.makePlaceholderNode)

        let participantClaimID = context.mountRoot.reserveTransitionParticipant()
        let initialPhase = context.mountRoot.consumeTransitionPhase(defaultAnimation: defaultAnimation)
        self.node = makeInitialNode(for: initialPhase, context: context, ctx: &ctx)

        if let participantClaimID {
            context.mountRoot.registerTransitionParticipant(
                claimID: participantClaimID,
                defaultAnimation: defaultAnimation,
                patchPhase: { phase, tx in
                    self.patchTransitionPhase(phase, tx: &tx)
                },
                isStillMounted: {
                    return self.node != nil
                },
                ctx: &ctx
            )
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
