final class FLIPAnimation<Value: CSSAnimatable> {
    private var node: DOM.Node
    private var animatedValue: AnimatedValue<Value>
    private var domAnimation: DOM.Animation?
    private var isDirty: Bool

    var isCompleted: Bool {
        !animatedValue.isAnimating
    }

    init(node: DOM.Node, first: Value, last: Value, transaction: Transaction, frameTime: Double) {
        self.node = node
        self.animatedValue = AnimatedValue(value: first)

        _ = self.animatedValue.setValueAndReturnIfAnimationWasStarted(last, transaction: transaction, frameTime: frameTime)
        isDirty = true
    }

    func cancel() {
        domAnimation?.cancel()
        domAnimation = nil
        animatedValue.cancelAnimation()
    }

    func commit(context: inout _CommitContext) {
        if isDirty {
            logTrace("committing dirty animation \(Value.CSSValue.styleKey)")
            isDirty = false
            let value = animatedValue.nextCSSAnimationValue(frameTime: context.currentFrameTime)

            switch value {
            case .single(_):
                logTrace("cancelling animation \(Value.CSSValue.styleKey)")
                domAnimation?.cancel()
                domAnimation = nil
            case .animated(let track):
                let effect = DOM.Animation.KeyframeEffect(.animated(track), isFirst: false)
                if let domAnimation = domAnimation {
                    domAnimation.update(effect)
                } else {
                    // TODO: find a better way to schedule a callback here
                    domAnimation = context.dom.animateElement(node, effect) { [scheduler = context.scheduler] in
                        scheduler.registerAnimation(
                            AnyAnimatable { context in
                                logTrace("CSS animation of \(Value.CSSValue.styleKey) completed, marking dirty")
                                self.animatedValue.progressToTime(context.currentFrameTime)
                                self.isDirty = true
                                // TODO: fix this nonsense
                                context.scheduler.addCommitAction { _ in }
                                return .completed
                            }
                        )
                    }
                }
            }
        }
    }
}
