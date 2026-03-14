import Reactivity

public final class _ForEachNode<Data, Content>: _Reconcilable
where Data: Collection, Content: _KeyReadableView, Content.Value: _Mountable {
    private var data: Data
    private var contentBuilder: @Sendable (Data.Element) -> Content
    private var keyedNode: _KeyedNode?
    private var context: _ViewContext
    private var trackingSession: TrackingSession? = nil

    public var depthInTree: Int
    var asFunctionNode: AnyFunctionNode!

    init(
        data: consuming Data,
        contentBuilder: @escaping @Sendable (Data.Element) -> Content,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        self.data = data
        self.contentBuilder = contentBuilder
        self.context = copy context
        self.depthInTree = context.functionDepth
        self.asFunctionNode = AnyFunctionNode(self)

        runFunctionInitial(ctx: &ctx)
    }

    func patch(
        data: consuming Data,
        contentBuilder: @escaping @Sendable (Data.Element) -> Content,
        tx: inout _TransactionContext
    ) {
        self.data = data
        self.contentBuilder = contentBuilder
        tx.addFunction(asFunctionNode)
    }

    func runFunction(tx: inout _TransactionContext) {
        self.trackingSession.take()?.cancel()

        let ((views, keys), session) = withReactiveTrackingSession {
            var views: [Content] = []
            var keys: [_ViewKey] = []
            let estimatedCount = data.underestimatedCount
            views.reserveCapacity(estimatedCount)
            keys.reserveCapacity(estimatedCount)

            for value in data {
                let view = contentBuilder(value)
                views.append(view)
                keys.append(view._key)
            }

            return (views, keys)
        } onWillSet: { [scheduler = tx.scheduler, asFunctionNode = asFunctionNode!] in
            scheduler.invalidateFunction(asFunctionNode)
        }

        self.trackingSession = session

        if keyedNode == nil {
            keyedNode = _KeyedNode(context: context)
        }

        keyedNode!.patch(
            keys,
            context: &tx,
            as: Content.Value._MountedNode.self,
            makeNode: { index, context, mountCtx in
                Content.Value._makeNode(views[index]._value, context: context, ctx: &mountCtx)
            },
            patchNode: { index, node, tx in
                Content.Value._patchNode(views[index]._value, node: &node, tx: &tx)
            }
        )
    }

    private func runFunctionInitial(ctx: inout _MountContext) {
        self.trackingSession.take()?.cancel()

        let ((views, keys), session) = withReactiveTrackingSession {
            var views: [Content] = []
            var keys: [_ViewKey] = []
            let estimatedCount = data.underestimatedCount
            views.reserveCapacity(estimatedCount)
            keys.reserveCapacity(estimatedCount)

            for value in data {
                let view = contentBuilder(value)
                views.append(view)
                keys.append(view._key)
            }

            return (views, keys)
        } onWillSet: { [scheduler = ctx.scheduler, asFunctionNode = asFunctionNode!] in
            scheduler.invalidateFunction(asFunctionNode)
        }

        self.trackingSession = session

        keyedNode = _KeyedNode(
            keys: keys,
            context: context,
            ctx: &ctx,
            makeNode: { index, context, mountCtx in
                Content.Value._makeNode(views[index]._value, context: context, ctx: &mountCtx)
            }
        )
    }

    public func unmount(_ context: inout _CommitContext) {
        self.trackingSession.take()?.cancel()
        let node = keyedNode.take()
        node?.unmount(&context)
    }
}

extension AnyFunctionNode {
    init(_ forEachNode: _ForEachNode<some Collection, some _KeyReadableView>) {
        self.identifier = ObjectIdentifier(forEachNode)
        self.depthInTree = forEachNode.depthInTree
        self.runUpdate = forEachNode.runFunction
    }
}
