import Reactivity

// FIXME EMBEDDED: these typealiases work around the embedded compiler failing
// to resolve Value.Body._MountedNode directly at some use sites.
public typealias _FunctionNode<Value: __FunctionView> = __FunctionNode<
    Value,
    Value.Body._MountedNode
>

public typealias _AnimatableFunctionNode<Value: __FunctionView & Animatable> =
    __AnimatableFunctionNode<Value, Value.Body._MountedNode>

public struct __FunctionNode<
    Value: __FunctionView,
    ChildNode: _Reconcilable & ~Copyable
>: ~Copyable, _Reconcilable
where ChildNode == Value.Body._MountedNode {
    private var core:
        _FunctionNodeCore<
            Value,
            ChildNode,
            SchedulableFunction<Value, Value.Body, ChildNode>
        >

    init(
        value: consuming Value,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        core = .init(value: value, context: context, ctx: &ctx)
    }

    mutating func patch(
        _ value: consuming Value,
        tx: inout _TransactionContext
    ) {
        core.patch(value, tx: &tx)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        core.unmount(&context)
    }
}

public struct __AnimatableFunctionNode<
    Value: __FunctionView & Animatable,
    ChildNode: _Reconcilable & ~Copyable
>: ~Copyable, _Reconcilable
where ChildNode == Value.Body._MountedNode {
    private var core:
        _FunctionNodeCore<
            Value,
            ChildNode,
            AnimatableFunction<Value, Value.Body, ChildNode>
        >

    init(
        value: consuming Value,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        core = .init(value: value, context: context, ctx: &ctx)
    }

    mutating func patch(
        _ value: consuming Value,
        tx: inout _TransactionContext
    ) {
        core.patch(value, tx: &tx)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        core.unmount(&context)
    }
}

private struct _FunctionNodeCore<
    Value: __FunctionView,
    ChildNode: _Reconcilable & ~Copyable,
    Function: _FunctionScheduler
>: ~Copyable
where
    ChildNode == Value.Body._MountedNode,
    Function.View == Value,
    Function.Child == Value.Body,
    Function.ChildNode == ChildNode
{
    let context: _ViewContext
    let depthInTree: Int
    var state: Value.__ViewState
    var lastValue: Value
    var storage: Storage

    enum Storage: ~Copyable {
        case inline(ChildNode)
        case box(Function)
    }

    init(
        value: consuming Value,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        depthInTree = context.functionDepth
        state = Value.__initializeState(from: value)

        var childContext = copy context
        childContext.functionDepth += 1
        self.context = childContext

        Value.__applyContext(context, to: &value)
        Value.__restoreState(state, in: &value)

        let (body, accessList) = withAccessTracking { value.body }
        lastValue = consume value

        let childNode = Value.Body._makeNode(
            body,
            context: self.context,
            ctx: &ctx
        )

        if accessList != nil || Function.boxesWithoutTracking {
            storage = .box(
                Storage.makeBox(
                    child: childNode,
                    value: lastValue,
                    depthInTree: depthInTree,
                    accessList: accessList,
                    scheduler: ctx.scheduler
                )
            )
        } else {
            storage = .inline(childNode)
        }
    }

    mutating func patch(
        _ newValue: consuming Value,
        tx: inout _TransactionContext
    ) {
        guard !Value.__areEqual(a: newValue, b: lastValue) else {
            return
        }

        Value.__applyContext(context, to: &newValue)
        Value.__restoreState(state, in: &newValue)

        storage.patch(newValue, depthInTree: depthInTree, tx: &tx)

        lastValue = consume newValue
    }

    consuming func unmount(_ context: inout _CommitContext) {
        switch storage {
        case .inline(var child):
            __noOpModifyForStupidWarning(&child)
            child.unmount(&context)
        case .box(let function):
            function.trackingSession.take()?.cancel()
            function.cancelAnimation()
            function.unmountChild(&context)
        }
    }

}

private extension _FunctionNodeCore.Storage where ChildNode: ~Copyable {
    static func makeBox(
        child: consuming ChildNode,
        value: borrowing Value,
        depthInTree: Int,
        accessList: ReactivePropertyAccessList?,
        scheduler: Scheduler
    ) -> Function {
        let function = Function(
            child: child,
            wiredValue: copy value,
            depthInTree: depthInTree
        )
        if let accessList {
            function.startTracking(for: accessList, scheduler: scheduler)
        }
        return function
    }

    mutating func patch(
        _ value: borrowing Value,
        depthInTree: Int,
        tx: inout _TransactionContext
    ) {
        switch self {
        case .inline(var child):
            let valueForBody = copy value
            let (body, accessList) = withAccessTracking {
                valueForBody.body
            }
            Value.Body._patchNode(body, node: &child, tx: &tx)

            if accessList != nil || Function.boxesWithoutTracking {
                self = .box(
                    Self.makeBox(
                        child: child,
                        value: value,
                        depthInTree: depthInTree,
                        accessList: accessList,
                        scheduler: tx.scheduler
                    )
                )
            } else {
                self = .inline(child)
            }

        case .box(let function):
            function.updateValue(value, tx: &tx)
            self = .box(function)
        }
    }
}

private protocol _FunctionScheduler<View, Child, ChildNode>: AnyObject {
    associatedtype View: __FunctionView
    associatedtype Child: _Mountable
    associatedtype ChildNode: _Reconcilable & ~Copyable

    static var boxesWithoutTracking: Bool { get }

    init(
        child: consuming ChildNode,
        wiredValue: View,
        depthInTree: Int
    )

    var trackingSession: TrackingSession? { get set }

    func startTracking(
        for accessList: ReactivePropertyAccessList,
        scheduler: Scheduler
    )
    func updateValue(
        _ value: borrowing View,
        tx: inout _TransactionContext
    )
    func cancelAnimation()
    func unmountChild(_ context: inout _CommitContext)
}

class SchedulableFunction<
    Value: __FunctionView,
    Body: _Mountable,
    MountedBody: _Reconcilable & ~Copyable
>: _SchedulableNode, _FunctionScheduler
where Body == Value.Body, MountedBody == Body._MountedNode {
    typealias View = Value
    typealias Child = Body
    typealias ChildNode = MountedBody

    class var boxesWithoutTracking: Bool { false }

    var child: MountedBody?
    var wiredValue: Value
    let patchChild: (consuming Body, inout MountedBody, inout _TransactionContext) -> Void

    required init(
        child: consuming MountedBody,
        wiredValue: Value,
        depthInTree: Int
    ) {
        self.child = .some(child)
        self.wiredValue = wiredValue
        patchChild = Body._patchNode
        super.init(depthInTree: depthInTree)
    }

    func updateValue(
        _ value: borrowing Value,
        tx: inout _TransactionContext
    ) {
        wiredValue = copy value
        runUpdate(tx: &tx)
    }

    override func runUpdate(tx: inout _TransactionContext) {
        let value = wiredValue
        render(value, tx: &tx)
    }

    final func render(
        _ value: consuming Value,
        tx: inout _TransactionContext
    ) {
        trackingSession.take()?.cancel()

        let (body, accessList) = withAccessTracking { value.body }
        if let accessList {
            startTracking(for: accessList, scheduler: tx.scheduler)
        }
        patchChild(body, &child!, &tx)
    }

    func cancelAnimation() {}

    final func unmountChild(_ context: inout _CommitContext) {
        child.take()?.unmount(&context)
    }
}

final class AnimatableFunction<
    Value: __FunctionView & Animatable,
    Body: _Mountable,
    MountedBody: _Reconcilable & ~Copyable
>: SchedulableFunction<Value, Body, MountedBody>
where Body == Value.Body, MountedBody == Body._MountedNode {
    override class var boxesWithoutTracking: Bool { true }

    var animatedValue: AnimatedValue<Value.Value>

    required init(
        child: consuming MountedBody,
        wiredValue: Value,
        depthInTree: Int
    ) {
        animatedValue = AnimatedValue(value: wiredValue.animatableValue)
        super.init(
            child: child,
            wiredValue: wiredValue,
            depthInTree: depthInTree
        )
    }

    override func updateValue(
        _ value: borrowing Value,
        tx: inout _TransactionContext
    ) {
        let didStartAnimation =
            animatedValue
            .setValueAndReturnIfAnimationWasStarted(
                value.animatableValue,
                transaction: tx.transaction,
                frameTime: tx.currentFrameTime
            )
        if didStartAnimation {
            tx.scheduler.registerAnimation(self)
        }

        wiredValue = copy value
        runUpdate(tx: &tx)
    }

    override func runUpdate(tx: inout _TransactionContext) {
        var value = wiredValue
        value.animatableValue = animatedValue.presentation
        render(value, tx: &tx)
    }

    override func progressAnimation(
        tx: inout _TransactionContext
    ) -> AnimationProgressResult {
        guard animatedValue.isAnimating else { return .completed }
        animatedValue.progressToTime(tx.currentFrameTime)
        runUpdate(tx: &tx)
        return animatedValue.isAnimating ? .stillRunning : .completed
    }

    override func cancelAnimation() {
        animatedValue.cancelAnimation()
    }
}

@_transparent
private func __noOpModifyForStupidWarning<R: ~Copyable>(
    _ value: inout R
) {
    // do nothing
}
