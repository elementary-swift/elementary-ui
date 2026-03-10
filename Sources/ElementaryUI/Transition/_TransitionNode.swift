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
    private var currentRemovalAnimationTime: Double?

    init(view: consuming _TransitionView<T, V>, context: borrowing _ViewContext, tx: inout _TransactionContext) {
        self.value = view
        placeholderView = PlaceholderContentView<T>(makeNodeFn: self.makePlaceholderNode)

        let transitionAnimation = tx.transaction.disablesAnimation ? nil : tx.transaction.animation ?? value.animation

        // the idea is that with disablesAnimation set to true, only the top-level transition will be animated after a mount will be animated
        guard let transitionAnimation else {
            self.node = AnyReconcilable(T.Body._makeNode(
                self.value.transition.body(content: placeholderView!, phase: .identity),
                context: context,
                tx: &tx
            ))
            return
        }

        tx.withModifiedTransaction {
            $0.disablesAnimation = true
            $0.animation = transitionAnimation
        } run: { tx in
            self.node = AnyReconcilable(T.Body._makeNode(
                self.value.transition.body(content: placeholderView!, phase: .willAppear),
                context: context,
                tx: &tx
            ))
        }

        // Schedule follow-up TX to patch to identity phase (triggers CSS transition)
        tx.scheduler.scheduleUpdate { [self] tx in
            guard let placeholderView = self.placeholderView else { return }
            tx.withModifiedTransaction {
                $0.animation = transitionAnimation
            } run: { tx in
                self.node?.modify(as: T.Body._MountedNode.self) { node in
                    T.Body._patchNode(
                        self.value.transition.body(content: placeholderView, phase: .identity),
                        node: &node,
                        tx: &tx
                    )
                }
            }
        }
    }

    func update(view: consuming _TransitionView<T, V>, context: inout _TransactionContext) {
        self.value = view

        if let placeholderNode {
            placeholderNode.node.modify(as: V._MountedNode.self) { node in
                V._patchNode(self.value.wrapped, node: &node, tx: &context)
            }
        }

        for placeholder in additionalPlaceholderNodes {
            placeholder.node.modify(as: V._MountedNode.self) { node in
                V._patchNode(self.value.wrapped, node: &node, tx: &context)
            }
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
                node?.modify(as: T.Body._MountedNode.self) { node in
                    T.Body._patchNode(
                        value.transition.body(content: placeholderView, phase: .didDisappear),
                        node: &node,
                        tx: &tx
                    )
                }
            }

            currentRemovalAnimationTime = tx.currentFrameTime

            tx.transaction.addAnimationCompletion(criteria: .removed) {
                [scheduler = tx.scheduler, frameTime = currentRemovalAnimationTime] in
                guard let currentTime = self.currentRemovalAnimationTime, currentTime == frameTime else { return }
                scheduler.scheduleUpdate { [self] tx in
                    self.node?.apply(.startRemoval, &tx)
                }
            }
        case .cancelRemoval:
            currentRemovalAnimationTime = nil
            // TODO: check this, stuff is for sure missing for reversible transitions
            node?.apply(.cancelRemoval, &tx)
            node?.modify(as: T.Body._MountedNode.self) { node in
                T.Body._patchNode(
                    value.transition.body(content: placeholderView, phase: .identity),
                    node: &node,
                    tx: &tx
                )
            }
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
