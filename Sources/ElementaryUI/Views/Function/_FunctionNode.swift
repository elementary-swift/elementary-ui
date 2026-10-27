import Reactivity

// NOTE: the implementation is split up like this to improve code size
// statically splitting out the animation machinery for non-animatable views helps with that

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
            SchedulableFunction<Value, ChildNode>
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
            AnimatableFunction<Value, ChildNode>
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
    Function.ChildNode == ChildNode
{
    let context: _ViewContext
    let state: Value.__ViewState
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
        let depthInTree = context.functionDepth
        state = Value.__initializeState(from: value)

        var childContext = copy context
        childContext.functionDepth += 1
        self.context = childContext

        Value.__applyContext(context, to: &value)
        Value.__restoreState(state, in: &value)

        var result = ReactiveTracking.track { value.body }
        lastValue = consume value
        let dependencies = result.dependencies.take()

        let childNode = Value.Body._makeNode(
            result.takeValue(),
            context: self.context,
            ctx: &ctx
        )

        storage = Storage.make(
            child: childNode,
            value: lastValue,
            depthInTree: depthInTree,
            dependencies: dependencies,
            scheduler: ctx.scheduler
        )
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

        storage.patch(
            newValue,
            childFunctionDepth: context.functionDepth,
            tx: &tx
        )

        lastValue = consume newValue
    }

    consuming func unmount(_ context: inout _CommitContext) {
        switch storage {
        case .inline(var child):
            __noOpModifyForStupidWarning(&child)
            child.unmount(&context)
        case .box(let function):
            function.unmountChild(&context)
        }
    }

}

private extension _FunctionNodeCore.Storage where ChildNode: ~Copyable {
    /// Boxes the child in a schedulable function only if it has something to observe.
    static func make(
        child: consuming ChildNode,
        value: borrowing Value,
        depthInTree: Int,
        dependencies: consuming ReactiveTracking.AccessedDependencies?,
        scheduler: Scheduler
    ) -> Self {
        guard dependencies != nil || Function.boxesWithoutTracking else {
            return .inline(child)
        }
        return .box(
            Function(
                child: child,
                wiredValue: copy value,
                depthInTree: depthInTree,
                scheduler: scheduler,
                tracking: dependencies
            )
        )
    }

    mutating func patch(
        _ value: borrowing Value,
        childFunctionDepth: Int,
        tx: inout _TransactionContext
    ) {
        switch self {
        case .inline(var child):
            let valueForBody = copy value
            var result = ReactiveTracking.track { valueForBody.body }
            let dependencies = result.dependencies.take()
            Value.Body._patchNode(result.takeValue(), node: &child, tx: &tx)

            self = Self.make(
                child: child,
                value: value,
                depthInTree: childFunctionDepth - 1,
                dependencies: dependencies,
                scheduler: tx.scheduler
            )

        case .box(let function):
            function.updateValue(value, tx: &tx)
            self = .box(function)
        }
    }
}

private protocol _FunctionScheduler<View, ChildNode>: AnyObject
where Self: _SchedulableNode {
    associatedtype View: __FunctionView
    associatedtype ChildNode: _Reconcilable & ~Copyable

    static var boxesWithoutTracking: Bool { get }

    init(
        child: consuming ChildNode,
        wiredValue: View,
        depthInTree: Int,
        scheduler: Scheduler,
        tracking dependencies: consuming ReactiveTracking.AccessedDependencies?
    )

    func updateValue(
        _ value: borrowing View,
        tx: inout _TransactionContext
    )
    func unmountChild(_ context: inout _CommitContext)
}

class SchedulableFunction<
    Value: __FunctionView,
    MountedBody: _Reconcilable & ~Copyable
>: _SchedulableNode, _FunctionScheduler
where MountedBody == Value.Body._MountedNode {
    typealias View = Value
    typealias ChildNode = MountedBody

    class var boxesWithoutTracking: Bool { false }

    var child: MountedBody?
    var wiredValue: Value

    required init(
        child: consuming MountedBody,
        wiredValue: Value,
        depthInTree: Int,
        scheduler: Scheduler,
        tracking dependencies: consuming ReactiveTracking.AccessedDependencies?
    ) {
        self.child = .some(child)
        self.wiredValue = wiredValue
        super.init(depthInTree: depthInTree, scheduler: scheduler, tracking: dependencies)
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
        guard let body = listener?.track({ value.body }) else { return }
        Value.Body._patchNode(body, node: &child!, tx: &tx)
    }

    func cancelAnimation() {}

    final func unmountChild(_ context: inout _CommitContext) {
        listener = nil
        cancelAnimation()
        child.take()?.unmount(&context)
    }
}

final class AnimatableFunction<
    Value: __FunctionView & Animatable,
    MountedBody: _Reconcilable & ~Copyable
>: SchedulableFunction<Value, MountedBody>
where MountedBody == Value.Body._MountedNode {
    override class var boxesWithoutTracking: Bool { true }

    var animatedValue: AnimatedValue<Value.Value>

    required init(
        child: consuming MountedBody,
        wiredValue: Value,
        depthInTree: Int,
        scheduler: Scheduler,
        tracking dependencies: consuming ReactiveTracking.AccessedDependencies?
    ) {
        animatedValue = AnimatedValue(value: wiredValue.animatableValue)
        super.init(
            child: child,
            wiredValue: wiredValue,
            depthInTree: depthInTree,
            scheduler: scheduler,
            tracking: dependencies
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
