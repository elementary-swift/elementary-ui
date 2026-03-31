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

        let (views, keys, session) = evaluateViewsAndKeys(
            scheduler: ctx.scheduler
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

        let (views, keys, session) = evaluateViewsAndKeys(
            scheduler: tx.scheduler
        )

        self.trackingSession = session

        container.patch(
            keys: keys,
            tx: &tx,
            makeNode: { index, context, mountCtx in
                AnyReconcilable(
                    Content.Value._makeNode(views[index]._value, context: context, ctx: &mountCtx)
                )
            },
            patchNode: { index, anyNode, tx in
                anyNode.modify(as: Content.Value._MountedNode.self) { node in
                    Content.Value._patchNode(views[index]._value, node: &node, tx: &tx)
                }
            }
        )
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        self.trackingSession.take()?.cancel()
        container.unmount(&context)
    }

    private func evaluateViewsAndKeys(
        scheduler: Scheduler
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
            onWillSet: { [scheduler, asFunctionNode] in
                scheduler.invalidateFunction(asFunctionNode)
            }
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
