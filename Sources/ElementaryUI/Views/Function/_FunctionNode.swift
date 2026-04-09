import Reactivity

// FIXME EMBEDDED: this is a hack to get the goshdarn Value.Body._MountedNode to work in embedded
// TODO: report swiftlang github issue
public typealias _FunctionNode<Value: __FunctionView> = __FunctionNode<Value, Value.Body._MountedNode>

public struct __FunctionNode<Value: __FunctionView, ChildNode: _Reconcilable & ~Copyable>: ~Copyable, _Reconcilable
where ChildNode == Value.Body._MountedNode {
    let context: _ViewContext
    let depthInTree: Int
    var state: Value.__ViewState
    var lastValue: Value

    var storage: Storage

    enum Storage: ~Copyable {
        case inline(ChildNode)
        case box(SchedulableFunction<Value, Value.Body, ChildNode>)
    }

    init(value: consuming Value, context: borrowing _ViewContext, ctx: inout _MountContext) {
        self.depthInTree = context.functionDepth
        self.state = Value.__initializeState(from: value)

        // TODO: make this better, this is weird
        var childContext = copy context
        childContext.functionDepth += 1
        self.context = childContext

        Value.__applyContext(context, to: &value)
        Value.__restoreState(self.state, in: &value)

        let (body, accessList) = withAccessTracking { value.body }

        self.lastValue = consume value

        let childNode = Value.Body._makeNode(body, context: self.context, ctx: &ctx)

        let animatableData = Value.__getAnimatableData(from: self.lastValue)
        if accessList != nil || !animatableData.isEmpty {
            let s = Storage.makeBox(
                child: childNode,
                value: self.lastValue,
                depthInTree: self.depthInTree,
                accessList: accessList,
                animatableData: animatableData,
                scheduler: ctx.scheduler
            )
            self.storage = .box(s)
        } else {
            self.storage = .inline(childNode)
        }
    }

    mutating func patch(_ newValue: consuming Value, tx: inout _TransactionContext) {
        guard !Value.__areEqual(a: newValue, b: lastValue) else {
            return
        }

        Value.__applyContext(self.context, to: &newValue)
        Value.__restoreState(self.state, in: &newValue)

        storage.patch(newValue, depthInTree: depthInTree, tx: &tx)

        lastValue = consume newValue
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        switch storage {
        case .inline(var child):
            child.unmount(&context)
        case .box(let s):
            s.trackingSession.take()?.cancel()
            s.unmountChild(&context)
            s.animatedValue.cancelAnimation()
        }
    }
}

// MARK: - Storage

extension __FunctionNode.Storage where ChildNode: ~Copyable {
    static func makeBox(
        child: consuming ChildNode,
        value: borrowing Value,
        depthInTree: Int,
        accessList: ReactivePropertyAccessList?,
        animatableData: AnimatableVector,
        scheduler: Scheduler
    ) -> SchedulableFunction<Value, Value.Body, ChildNode> {
        let s = SchedulableFunction(
            child: child,
            animatedValue: AnimatedValue(value: animatableData),
            wiredValue: copy value,
            depthInTree: depthInTree
        )
        if let accessList {
            s.startTracking(for: accessList, scheduler: scheduler)
        }
        return s
    }

    mutating func patch(
        _ value: borrowing Value,
        depthInTree: Int,
        tx: inout _TransactionContext
    ) {
        switch self {
        case .inline(var child):
            let v = copy value
            let (body, accessList) = withAccessTracking { v.body }
            Value.Body._patchNode(body, node: &child, tx: &tx)

            let animatableData = Value.__getAnimatableData(from: value)
            if accessList != nil || !animatableData.isEmpty {
                let s = Self.makeBox(
                    child: child,
                    value: value,
                    depthInTree: depthInTree,
                    accessList: accessList,
                    animatableData: animatableData,
                    scheduler: tx.scheduler
                )
                self = .box(s)
            } else {
                self = .inline(child)
            }

        case .box(let s):
            s.trackingSession.take()?.cancel()

            let didStartAnimation = s.animatedValue
                .setValueAndReturnIfAnimationWasStarted(
                    Value.__getAnimatableData(from: value),
                    transaction: tx.transaction,
                    frameTime: tx.currentFrameTime
                )
            if didStartAnimation {
                tx.scheduler.registerAnimation(s)
            }

            s.wiredValue = copy value
            s.runUpdate(tx: &tx)
            self = .box(s)
        }
    }
}

final class SchedulableFunction<
    Value: __FunctionView,
    Child: _Mountable,
    ChildNode: _Reconcilable & ~Copyable
>: _SchedulableNode
where Child == Value.Body, ChildNode == Child._MountedNode {
    var child: ChildNode?
    var animatedValue: AnimatedValue<AnimatableVector>
    var wiredValue: Value
    var patchChild: (consuming Child, inout ChildNode, inout _TransactionContext) -> Void

    init(
        child: consuming ChildNode,
        animatedValue: consuming AnimatedValue<AnimatableVector>,
        wiredValue: Value,
        depthInTree: Int
    ) {
        self.child = .some(child)
        self.animatedValue = animatedValue
        self.wiredValue = wiredValue
        self.patchChild = Child._patchNode
        super.init(depthInTree: depthInTree)
    }

    override func runUpdate(tx: inout _TransactionContext) {
        var v = wiredValue
        if !animatedValue.model.isEmpty {
            Value.__setAnimatableData(animatedValue.presentation.animatableVector, to: &v)
        }
        let (body, accessList) = withAccessTracking { v.body }
        if let accessList {
            startTracking(for: accessList, scheduler: tx.scheduler)
        }
        patchChild(body, &child!, &tx)
    }

    override func progressAnimation(tx: inout _TransactionContext) -> AnimationProgressResult {
        guard animatedValue.isAnimating else { return .completed }
        animatedValue.progressToTime(tx.currentFrameTime)
        trackingSession.take()?.cancel()
        runUpdate(tx: &tx)
        return animatedValue.isAnimating ? .stillRunning : .completed
    }

    func unmountChild(_ context: inout _CommitContext) {
        child.take()?.unmount(&context)
    }
}
