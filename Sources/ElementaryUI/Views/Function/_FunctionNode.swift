import Reactivity

// TODO: find a better name for this, "function node" is weird terminology

// NOTE: ChildNode must be specified as extra argument to avoid a compiler error in embedded
// FIXME: embedded - try with embedded main-snapshot build, revert extra argument if it works
public final class _FunctionNode<Value, ChildNode>
where Value: __FunctionView, ChildNode: _Reconcilable, ChildNode == Value.Body._MountedNode {
    private var state: Value.__ViewState?
    private var value: Value?
    private var context: _ViewContext?
    private var animatedValue: AnimatedValue<AnimatableVector>
    private var trackingSession: TrackingSession? = nil

    public var depthInTree: Int

    var asFunctionNode: AnyFunctionNode!

    public var identifier: String {
        "\(depthInTree):\(ObjectIdentifier(self).hashValue)"
    }

    var child: Value.Body._MountedNode?

    init(
        value: consuming Value,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) {
        self.depthInTree = context.functionDepth

        self.state = Value.__initializeState(from: value)
        self.animatedValue = AnimatedValue(value: Value.__getAnimatableData(from: value))
        Value.__applyContext(context, to: &value)
        Value.__restoreState(state!, in: &value)

        self.value = value
        self.context = copy context
        self.context!.functionDepth += 1

        self.asFunctionNode = AnyFunctionNode(self)

        logTrace("added function \(identifier)")

        // we need to break here for scoped reactivity tracking
        tx.addFunction(asFunctionNode)
    }

    func patch(_ value: consuming Value, tx: inout _TransactionContext) {
        precondition(self.value != nil, "value must be set")
        precondition(self.context != nil, "context must be set")

        let needsRerender = !Value.__areEqual(a: value, b: self.value!)

        // NOTE: the idea is that way always store a "wired-up" value, so that we can re-run the function for free
        // the equality check is generated to exclude State and Context from the equality check
        Value.__applyContext(self.context!, to: &value)
        Value.__restoreState(state!, in: &value)
        self.value = value

        if needsRerender {
            let didStartAnimation = animatedValue.setValueAndReturnIfAnimationWasStarted(
                Value.__getAnimatableData(from: self.value!),
                transaction: tx.transaction,
                frameTime: tx.currentFrameTime
            )

            if didStartAnimation == true {
                tx.scheduler.registerAnimation(.init(progressAnimation: self.progressAnimation(_:)))
            }

            tx.addFunction(asFunctionNode)
        }
    }

    func progressAnimation(_ tx: inout _TransactionContext) -> AnimationProgressResult {
        assert(!animatedValue.model.isEmpty, "animation should never be called without an animatable value")
        guard animatedValue.isAnimating else { return .completed }

        animatedValue.progressToTime(tx.currentFrameTime)
        runFunction(tx: &tx)

        return animatedValue.isAnimating ? .stillRunning : .completed
    }

    func runFunction(tx: inout _TransactionContext) {
        logTrace("running function \(identifier)")

        precondition(self.value != nil, "value must be set")
        precondition(self.context != nil, "context must be set")

        // create a copy of the value to avoid mutating the original value, especially for animations
        var value = self.value!

        if !animatedValue.model.isEmpty {
            Value.__setAnimatableData(animatedValue.presentation.animatableVector, to: &value)
        }

        self.trackingSession.take()?.cancel()

        let (newContent, session) = withReactiveTrackingSession {
            value.body
        } onWillSet: { [scheduler = tx.scheduler, asFunctionNode = asFunctionNode!] in
            scheduler.invalidateFunction(asFunctionNode)
        }

        self.trackingSession = session

        if child == nil {
            self.child = Value.Body._makeNode(newContent, context: context!, tx: &tx)
        } else {
            Value.Body._patchNode(newContent, node: child!, tx: &tx)
        }
    }
}

extension _FunctionNode: _Reconcilable {

    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        child?.collectChildren(&ops, &context)
    }

    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        child?.apply(op, &tx)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        self.trackingSession.take()?.cancel()

        let c = self.child.take()
        c?.unmount(&context)

        self.animatedValue.cancelAnimation()
        self.state = nil
        self.value = nil
        self.context = nil
    }
}

extension AnyFunctionNode {
    init(_ function: _FunctionNode<some __FunctionView, some _Reconcilable>) {
        self.identifier = ObjectIdentifier(function)
        self.depthInTree = function.depthInTree
        self.runUpdate = function.runFunction
    }
}
