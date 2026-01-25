public final class _TransitionNode<T: Transition, V: View>: _Reconcilable {
    private var value: _TransitionView<T, V>
    private var node: T.Body._MountedNode?

    private var placeholderView: PlaceholderContentView<T>?
    private var placeholderNode: _PlaceholderNode?
    // a transition can theoretically duplicate the content node, but it will be rare
    private var additionalPlaceholderNodes: [_PlaceholderNode] = []
    private var currentRemovalAnimationTime: Double?

    init(view: consuming _TransitionView<T, V>, context: borrowing _ViewContext, tx: inout _TransactionContext) {
        self.value = view
        placeholderView = PlaceholderContentView<T>(makeNodeFn: self.makePlaceholderNode)

        let transitionAnimation = tx.transaction.disablesAnimation ? nil : tx.transaction.animation ?? value.animation

        // the idea is that with disablesAnimation set to true, only the top-level transition will be animated after a mount will be animated
        guard let transitionAnimation else {
            self.node = T.Body._makeNode(
                self.value.transition.body(content: placeholderView!, phase: .identity),
                context: context,
                tx: &tx
            )
            return
        }

        tx.withModifiedTransaction {
            $0.disablesAnimation = true
            $0.animation = transitionAnimation
        } run: { tx in
            self.node = T.Body._makeNode(
                self.value.transition.body(content: placeholderView!, phase: .willAppear),
                context: context,
                tx: &tx
            )
        }

        // Schedule follow-up TX to patch to identity phase (triggers CSS transition)
        tx.scheduler.scheduleUpdate { [self] tx in
            guard let node = self.node, let placeholderView = self.placeholderView else { return }
            tx.withModifiedTransaction {
                $0.animation = transitionAnimation
            } run: { tx in
                T.Body._patchNode(
                    self.value.transition.body(content: placeholderView, phase: .identity),
                    node: node,
                    tx: &tx
                )
            }
        }
    }

    func update(view: consuming _TransitionView<T, V>, context: inout _TransactionContext) {
        self.value = view

        if let placeholderNode {
            V._patchNode(self.value.wrapped, node: placeholderNode.node.unwrap(), tx: &context)
        }

        for placeholder in additionalPlaceholderNodes {
            V._patchNode(self.value.wrapped, node: placeholder.node.unwrap(), tx: &context)
        }
    }

    private func makePlaceholderNode(context: borrowing _ViewContext, tx: inout _TransactionContext) -> _PlaceholderNode {
        let node = _PlaceholderNode(node: AnyReconcilable(V._makeNode(value.wrapped, context: context, tx: &tx)))
        if placeholderNode == nil {
            placeholderNode = node
        } else {
            additionalPlaceholderNodes.append(node)
        }
        return node
    }

    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        guard let placeholderView = placeholderView else { return }
        switch op {
        case .startRemoval:
            let transitionAnimation = tx.transaction.disablesAnimation ? nil : tx.transaction.animation ?? value.animation

            // if no animation is set, we just pass down removal op
            guard let transitionAnimation else {
                node?.apply(op, &tx)
                return
            }

            tx.withModifiedTransaction {
                $0.animation = transitionAnimation
            } run: { tx in
                node?.apply(.markAsLeaving, &tx)

                // the patch does not go past the placeholder, so this only animates the transition
                T.Body._patchNode(
                    value.transition.body(content: placeholderView, phase: .didDisappear),
                    node: node!,
                    tx: &tx
                )
            }

            currentRemovalAnimationTime = tx.currentFrameTime

            tx.transaction.addAnimationCompletion(criteria: .removed) {
                [scheduler = tx.scheduler, frameTime = currentRemovalAnimationTime] in
                guard let currentTime = self.currentRemovalAnimationTime, currentTime == frameTime else { return }
                scheduler.scheduleUpdate { [self] tx in
                    guard let node = self.node else { return }
                    node.apply(.startRemoval, &tx)
                }
            }
        case .cancelRemoval:
            currentRemovalAnimationTime = nil
            // TODO: check this, stuff is for sure missing for reversible transitions
            node?.apply(.cancelRemoval, &tx)
            T.Body._patchNode(
                value.transition.body(content: placeholderView, phase: .identity),
                node: node!,
                tx: &tx
            )
        case .markAsMoved:
            node?.apply(op, &tx)
        case .markAsLeaving:
            node?.apply(op, &tx)
        }
    }

    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        node?.collectChildren(&ops, &context)
    }

    public func unmount(_ context: inout _CommitContext) {
        node?.unmount(&context)

        node = nil
        placeholderNode = nil
        additionalPlaceholderNodes.removeAll()
    }
}
