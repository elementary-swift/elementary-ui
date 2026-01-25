final class MountedStyleModifier<Instance: CSSAnimatedValueInstance>: Unmountable, Invalidateable {
    let accessor: DOM.StyleAccessor
    var values: [Instance]

    let node: DOM.Node
    var animations: [DOM.Animation]

    var isDirty: Bool = false

    init(_ node: DOM.Node, _ layers: [Instance], _ context: inout _CommitContext) {
        self.node = node
        self.accessor = context.dom.makeStyleAccessor(node, cssName: Instance.CSSValue.styleKey)
        self.values = layers
        self.animations = []

        let selfAsTarget = AnyInvalidateable(self)
        for value in values {
            value.setTarget(selfAsTarget)
        }

        updateDOMNode(&context)
    }

    func invalidate(_ context: inout _TransactionContext) {
        guard !isDirty else { return }
        isDirty = true
        context.scheduler.addCommitAction(updateDOMNode(_:))
    }

    func updateDOMNode(_ context: inout _CommitContext) {
        if let combined = reduceCombinedSingleValue() {
            clearAllAnimations()
            accessor.set(combined.cssString)
        } else {
            startOrUpdateAnimations(&context)
        }

        isDirty = false
        for value in values {
            value.isDirty = false
        }
    }

    func unmount(_ context: inout _CommitContext) {
        for value in values {
            value.unmount(&context)
        }
        values.removeAll()
    }

    private func clearAllAnimations() {
        guard !animations.isEmpty else { return }
        for animation in animations {
            animation.cancel()
        }
        animations.removeAll(keepingCapacity: true)
    }

    private func startOrUpdateAnimations(_ context: inout _CommitContext) {
        if animations.isEmpty {
            logTrace("starting animations")
            animations.reserveCapacity(values.count)

            for (index, value) in values.enumerated() {
                let progressAnimation = value.progressAnimation(_:)
                animations.append(
                    context.dom.animateElement(
                        node,
                        DOM.Animation.KeyframeEffect(value.value, isFirst: index == 0)
                    ) { [scheduler = context.scheduler, progressAnimation] in
                        logTrace("animation finished")
                        scheduler.scheduleUpdate(progressAnimation)
                    }
                )
            }
        } else {
            assert(animations.count == values.count, "animations and values must have the same count")
            for (index, (animation, value)) in zip(animations, values).enumerated() {
                guard value.isDirty else { continue }
                logTrace("updating animation index \(index)")
                animation.update(DOM.Animation.KeyframeEffect(value.value, isFirst: index == 0))
            }
        }
    }

    private func reduceCombinedSingleValue() -> Instance.CSSValue? {
        guard let first = values.first?.value.singleValue else { return nil }
        var combined = first
        for layer in values.dropFirst() {
            guard let next = layer.value.singleValue else { return nil }
            combined.combineWith(next)
        }
        return combined
    }
}
