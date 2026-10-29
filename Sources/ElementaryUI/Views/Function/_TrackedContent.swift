import Reactivity

/// Mounts `content(input)` in its own scheduled node, so reactive reads made while building
/// the content are tracked by (and re-run) this node alone.
public struct _TrackedContent<Input, Content: _Mountable>: _Mountable {
    public typealias _MountedNode = _TrackedNode<Input, Content>

    var input: Input
    var content: (Input) -> Content

    init(input: Input, content: @escaping (Input) -> Content) {
        self.input = input
        self.content = content
    }

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(view, context: context, ctx: &ctx)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.patch(view, tx: &tx)
    }
}

public struct _TrackedNode<Input, Content: _Mountable>: ~Copyable, _Reconcilable {
    private let depthInTree: Int
    private var storage: Storage

    init(
        _ view: consuming _TrackedContent<Input, Content>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        depthInTree = context.functionDepth
        var childContext = copy context
        childContext.functionDepth += 1

        var dependencies: ReactiveTracking.AccessedDependencies?
        let content = ReactiveTracking.track(into: &dependencies) { view.content(view.input) }
        let child = Content._makeNode(content, context: childContext, ctx: &ctx)

        storage = Storage(
            child: child,
            view: view,
            dependencies: dependencies,
            depthInTree: depthInTree,
            scheduler: ctx.scheduler
        )
    }

    mutating func patch(
        _ view: consuming _TrackedContent<Input, Content>,
        tx: inout _TransactionContext
    ) {
        storage.patch(view, depthInTree: depthInTree, tx: &tx)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        storage.unmount(&context)
    }

    // Kept inline until the content reads reactive state, then boxed so it can be scheduled.
    private enum Storage: ~Copyable {
        case inline(Content._MountedNode)
        case box(TrackedFunction<Input, Content>)

        init(
            child: consuming Content._MountedNode,
            view: consuming _TrackedContent<Input, Content>,
            dependencies: consuming ReactiveTracking.AccessedDependencies?,
            depthInTree: Int,
            scheduler: Scheduler
        ) {
            guard let dependencies else {
                self = .inline(child)
                return
            }
            let function = TrackedFunction(child: child, view: view, depthInTree: depthInTree)
            function.startTracking(dependencies, scheduler: scheduler)
            self = .box(function)
        }

        mutating func patch(
            _ view: consuming _TrackedContent<Input, Content>,
            depthInTree: Int,
            tx: inout _TransactionContext
        ) {
            switch self {
            case .inline(var child):
                var dependencies: ReactiveTracking.AccessedDependencies?
                let content = ReactiveTracking.track(into: &dependencies) { view.content(view.input) }
                Content._patchNode(content, node: &child, tx: &tx)

                self = Storage(
                    child: child,
                    view: view,
                    dependencies: dependencies,
                    depthInTree: depthInTree,
                    scheduler: tx.scheduler
                )

            case .box(let function):
                function.update(view, tx: &tx)
                self = .box(function)
            }
        }

        consuming func unmount(_ context: inout _CommitContext) {
            switch consume self {
            case .inline(let child):
                child.unmount(&context)
            case .box(let function):
                function.unmount(&context)
            }
        }
    }
}

final class TrackedFunction<Input, Content: _Mountable>: SchedulableNode {
    private var child: Content._MountedNode?
    private var view: _TrackedContent<Input, Content>

    init(child: consuming Content._MountedNode, view: _TrackedContent<Input, Content>, depthInTree: Int) {
        self.child = .some(child)
        self.view = view
        super.init(depthInTree: depthInTree)
    }

    func update(_ view: consuming _TrackedContent<Input, Content>, tx: inout _TransactionContext) {
        self.view = view
        runUpdate(tx: &tx)
    }

    override func runUpdate(tx: inout _TransactionContext) {
        let body = trackDependencies(scheduler: tx.scheduler) { view.content(view.input) }
        Content._patchNode(body, node: &child!, tx: &tx)
    }

    func unmount(_ context: inout _CommitContext) {
        stopTracking()
        child.take()?.unmount(&context)
    }
}
