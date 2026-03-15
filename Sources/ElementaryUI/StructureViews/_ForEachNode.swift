import Reactivity

public final class _ForEachNode<Data, Content>: _Reconcilable
where Data: Collection, Content: _KeyReadableView, Content.Value: _Mountable {
    private typealias Evaluation = (views: [Content], keys: [_ViewKey], session: TrackingSession)

    private var data: Data
    private var contentBuilder: @Sendable (Data.Element) -> Content
    private var trackingSession: TrackingSession? = nil
    private var container: MountContainer!
    private var asFunctionNode: AnyFunctionNode!

    init(
        data: consuming Data,
        contentBuilder: @escaping @Sendable (Data.Element) -> Content,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        self.data = data
        self.contentBuilder = contentBuilder

        self.asFunctionNode = AnyFunctionNode(self, depthInTree: context.functionDepth)

        let (views, keys, session) = Self.evaluateViewsAndKeys(
            data: self.data,
            contentBuilder: self.contentBuilder,
            onWillSet: { [scheduler = ctx.scheduler, asFunctionNode] in
                scheduler.invalidateFunction(asFunctionNode)
            }
        )

        self.trackingSession = session

        let containerContext = copy context
        self.container = MountContainer(
            mountedKeys: keys,
            context: consume containerContext,
            ctx: &ctx,
            makeNode: { index, context, mountCtx in
                Content.Value._makeNode(views[index]._value, context: context, ctx: &mountCtx)
            }
        )

        ctx.appendContainer(container)
    }

    func patch(
        data: consuming Data,
        contentBuilder: @escaping @Sendable (Data.Element) -> Content,
        tx: inout _TransactionContext
    ) {
        self.data = data
        self.contentBuilder = contentBuilder
        runFunction(tx: &tx)
    }

    func runFunction(tx: inout _TransactionContext) {
        self.trackingSession.take()?.cancel()

        let (views, keys, session) = evaluateViewsAndKeys(scheduler: tx.scheduler)

        self.trackingSession = session

        container.patch(
            keys: keys,
            tx: &tx,
            makeNode: { index, context, mountCtx in
                Content.Value._makeNode(views[index]._value, context: context, ctx: &mountCtx)
            },
            patchNode: { index, node, tx in
                Content.Value._patchNode(views[index]._value, node: &node, tx: &tx)
            }
        )
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        self.trackingSession.take()?.cancel()
        container.unmount(&context)
    }

    private static func makeOnWillSet(
        scheduler: Scheduler,
        functionNode: AnyFunctionNode
    ) -> @Sendable () -> Void {
        {
            scheduler.invalidateFunction(functionNode)
        }
    }

    private func makeOnWillSet(scheduler: Scheduler) -> @Sendable () -> Void {
        Self.makeOnWillSet(scheduler: scheduler, functionNode: asFunctionNode)
    }

    private func evaluateViewsAndKeys(scheduler: Scheduler) -> Evaluation {
        Self.evaluateViewsAndKeys(
            data: data,
            contentBuilder: contentBuilder,
            onWillSet: makeOnWillSet(scheduler: scheduler)
        )
    }

    private static func evaluateViewsAndKeys(
        data: Data,
        contentBuilder: @escaping @Sendable (Data.Element) -> Content,
        onWillSet: @escaping @Sendable () -> Void
    ) -> Evaluation {
        let ((views, keys), session) = withReactiveTrackingSession(
            {
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
            },
            onWillSet: onWillSet
        )

        return (views, keys, session)
    }
}

extension AnyFunctionNode {
    init(_ node: _ForEachNode<some Collection, some _KeyReadableView>, depthInTree: Int) {
        self.identifier = ObjectIdentifier(node)
        self.depthInTree = depthInTree
        self.runUpdate = node.runFunction
    }
}
