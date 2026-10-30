import Reactivity

/// Mounts `content(input)` in its own scheduled node, so reactive reads made while building
/// the content are tracked by (and re-run) this node alone.
struct _TrackedContent<Input, Content: _Mountable>: _Mountable {
    typealias _MountedNode = _TrackedNode<Input, Content>

    var input: Input
    var content: (Input) -> Content

    init(input: Input, content: @escaping (Input) -> Content) {
        self.input = input
        self.content = content
    }

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(view, context: context, ctx: &ctx)
    }

    static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.patch(view, tx: &tx)
    }
}

// A single reference, so that type-erased rows are stored without a box.
struct _TrackedNode<Input, Content: _Mountable>: ~Copyable, _Reconcilable {
    private let function: TrackedFunction<Input, Content>

    init(
        _ view: consuming _TrackedContent<Input, Content>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        function = TrackedFunction(view, context: context, ctx: &ctx)
    }

    mutating func patch(
        _ view: consuming _TrackedContent<Input, Content>,
        tx: inout _TransactionContext
    ) {
        function.update(view, tx: &tx)
    }

    consuming func unmount(_ context: inout _CommitContext) {
        function.unmount(&context)
    }
}

final class TrackedFunction<Input, Content: _Mountable>: SchedulableNode {
    private var child: Content._MountedNode?
    private var view: _TrackedContent<Input, Content>

    init(
        _ view: consuming _TrackedContent<Input, Content>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        var childContext = copy context
        childContext.functionDepth += 1

        var dependencies: ReactiveTracking.AccessedDependencies?
        let content = ReactiveTracking.track(into: &dependencies) { view.content(view.input) }
        child = Content._makeNode(content, context: childContext, ctx: &ctx)
        self.view = view
        super.init(depthInTree: context.functionDepth)

        if let dependencies = dependencies.take() {
            startTracking(dependencies, scheduler: ctx.scheduler)
        }
    }

    func update(_ view: consuming _TrackedContent<Input, Content>, tx: inout _TransactionContext) {
        self.view = view
        update(tx: &tx)
    }

    override func performUpdate(tx: inout _TransactionContext) {
        let body = trackDependencies(scheduler: tx.scheduler) { view.content(view.input) }
        Content._patchNode(body, node: &child!, tx: &tx)
    }

    func unmount(_ context: inout _CommitContext) {
        stopScheduling()
        child.take()?.unmount(&context)
    }
}
