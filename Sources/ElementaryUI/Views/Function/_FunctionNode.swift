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
    ChildNode: ~Copyable
>: ~Copyable
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
}

public struct __AnimatableFunctionNode<
    Value: __FunctionView & Animatable,
    ChildNode: ~Copyable
>: ~Copyable
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
}

private struct _FunctionNodeCore<
    Value: __FunctionView,
    ChildNode: ~Copyable,
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

        var dependencies: ReactiveTracking.AccessedDependencies?
        let body = ReactiveTracking.track(into: &dependencies) { value.body }
        lastValue = consume value

        let childNode = Value.Body._makeNode(
            body,
            context: self.context,
            ctx: &ctx
        )

        // Environment slots are fixed for the node's lifetime, so readers register once, here.
        if dependencies != nil || Function.boxesWithoutTracking || Value.__readsEnvironment {
            let function = Storage.makeBox(
                child: childNode,
                value: lastValue,
                depthInTree: depthInTree,
                dependencies: dependencies,
                scheduler: ctx.scheduler
            )
            if Value.__readsEnvironment {
                Value.__visitEnvironment(of: lastValue, function.addEnvironmentDependency)
            }
            if Value.__readsEnvironment || Function.boxesWithoutTracking {
                // after the child registered, so it unmounts first
                ctx.registerUnmount(function)
            }
            storage = .box(function)
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

        storage.patch(
            &newValue,
            childFunctionDepth: context.functionDepth,
            tx: &tx
        )

        lastValue = consume newValue
    }

    var mountedBox: Function? {
        switch storage {
        case .box(let function): function
        case .inline: nil
        }
    }
}

private extension _FunctionNodeCore.Storage where ChildNode: ~Copyable {
    static func makeBox(
        child: consuming ChildNode,
        value: borrowing Value,
        depthInTree: Int,
        dependencies: consuming ReactiveTracking.AccessedDependencies?,
        scheduler: Scheduler
    ) -> Function {
        let function = Function(
            child: child,
            wiredValue: copy value,
            depthInTree: depthInTree
        )
        if let dependencies {
            function.startTracking(dependencies, scheduler: scheduler)
        }
        return function
    }

    // `value` is inout so the tracking closure can read it without a copy.
    mutating func patch(
        _ value: inout Value,
        childFunctionDepth: Int,
        tx: inout _TransactionContext
    ) {
        switch self {
        case .inline(var child):
            var dependencies: ReactiveTracking.AccessedDependencies?
            let body = ReactiveTracking.track(into: &dependencies) { value.body }
            Value.Body._patchNode(body, node: &child, tx: &tx)

            if dependencies != nil || Function.boxesWithoutTracking {
                self = .box(
                    Self.makeBox(
                        child: child,
                        value: value,
                        depthInTree: childFunctionDepth - 1,
                        dependencies: dependencies,
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

private protocol _FunctionScheduler<View, ChildNode>: AnyObject
where Self: SchedulableNode {
    associatedtype View: __FunctionView
    associatedtype ChildNode: ~Copyable

    static var boxesWithoutTracking: Bool { get }

    init(
        child: consuming ChildNode,
        wiredValue: View,
        depthInTree: Int
    )

    func updateValue(
        _ value: borrowing View,
        tx: inout _TransactionContext
    )
}

class SchedulableFunction<
    Value: __FunctionView,
    MountedBody: ~Copyable
>: SchedulableNode, _FunctionScheduler
where MountedBody == Value.Body._MountedNode {
    typealias View = Value
    typealias ChildNode = MountedBody

    class var boxesWithoutTracking: Bool { false }

    var child: MountedBody
    var wiredValue: Value

    required init(
        child: consuming MountedBody,
        wiredValue: Value,
        depthInTree: Int
    ) {
        self.child = child
        self.wiredValue = wiredValue
        super.init(depthInTree: depthInTree)
    }

    func updateValue(
        _ value: borrowing Value,
        tx: inout _TransactionContext
    ) {
        wiredValue = copy value
        update(tx: &tx)
    }

    override func performUpdate(tx: inout _TransactionContext) {
        let body = trackDependencies(scheduler: tx.scheduler) { wiredValue.body }
        Value.Body._patchNode(body, node: &child, tx: &tx)
    }

    final func render(
        _ value: consuming Value,
        tx: inout _TransactionContext
    ) {
        let body = trackDependencies(scheduler: tx.scheduler) { value.body }
        Value.Body._patchNode(body, node: &child, tx: &tx)
    }

    override func unmount(_ context: inout _CommitContext) {
        if Value.__readsEnvironment {
            Value.__visitEnvironment(of: wiredValue, removeEnvironmentDependency)
        }
        super.unmount(&context)
    }
}

final class AnimatableFunction<
    Value: __FunctionView & Animatable,
    MountedBody: ~Copyable
>: SchedulableFunction<Value, MountedBody>
where MountedBody == Value.Body._MountedNode {
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
        update(tx: &tx)
    }

    override func performUpdate(tx: inout _TransactionContext) {
        var value = wiredValue
        value.animatableValue = animatedValue.presentation
        render(value, tx: &tx)
    }

    override func progressAnimation(
        tx: inout _TransactionContext
    ) -> AnimationProgressResult {
        guard animatedValue.isAnimating else { return .completed }
        animatedValue.progressToTime(tx.currentFrameTime)
        update(tx: &tx)
        return animatedValue.isAnimating ? .stillRunning : .completed
    }

    // A running animation retains the box; it must not update removed content.
    override func unmount(_ context: inout _CommitContext) {
        super.unmount(&context)
        animatedValue.cancelAnimation()
    }
}
