import BasicContainers
import Reactivity

// TODO: refactor this entire thing - we need to make the key list without the views, and the resolve the views just off the data....
public final class _ForEachNode<Data, Content>: _Reconcilable
where Data: Collection, Content: _KeyReadableView, Content.Value: _Mountable {
    private var data: Data
    private var contentBuilder: @Sendable (Data.Element) -> Content
    private var trackingSession: TrackingSession? = nil
    private var container: MountContainer!
    private var asFunctionNode: AnyFunctionNode!

    private var keysScratch: UniqueArray<_ViewKey> = .init()
    private var viewsScratch: [Content] = .init()  // TODO: remove this once we refactored everything

    init(
        data: consuming Data,
        contentBuilder: @escaping @Sendable (Data.Element) -> Content,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        self.data = data
        self.contentBuilder = contentBuilder

        self.asFunctionNode = AnyFunctionNode(self, depthInTree: context.functionDepth)

        let session = evaluateViewsAndKeys(scheduler: ctx.scheduler)

        self.trackingSession = session

        self.container = MountContainer(
            mountedKeyStorage: keysScratch.span,
            context: context,
            ctx: &ctx,
            makeNode: { index, context, mountCtx in
                Content.Value._makeNode(self.viewsScratch[index]._value, context: context, ctx: &mountCtx)
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

    borrowing func runFunction(tx: inout _TransactionContext) {
        self.trackingSession.take()?.cancel()

        let session = evaluateViewsAndKeys(
            scheduler: tx.scheduler,
        )

        self.trackingSession = session

        container.patch(
            keys: self.keysScratch.span,
            tx: &tx,
            makeNode: { [viewsScratch] index, context, mountCtx in
                AnyReconcilable(
                    Content.Value._makeNode(viewsScratch[index]._value, context: context, ctx: &mountCtx)
                )
            },
            patchNode: { [viewsScratch] index, anyNode, tx in
                anyNode.modify(as: Content.Value._MountedNode.self) { node in
                    Content.Value._patchNode(viewsScratch[index]._value, node: &node, tx: &tx)
                }
            }
        )
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        self.trackingSession.take()?.cancel()
        container.unmount(&context)
    }

    private func evaluateViewsAndKeys(
        scheduler: Scheduler,
    ) -> TrackingSession {

        viewsScratch.reserveCapacity(data.underestimatedCount)
        keysScratch.reserveCapacity(data.underestimatedCount)

        viewsScratch.removeAll(keepingCapacity: true)
        keysScratch.removeAll(keepingCapacity: true)

        let (_, session) = withReactiveTrackingSession {
            for value in data {
                let view = contentBuilder(value)
                self.viewsScratch.append(view)
                self.keysScratch.append(view._key)
            }
        } onWillSet: { [scheduler, asFunctionNode] in
            scheduler.invalidateFunction(asFunctionNode)
        }

        return session
    }
}

extension AnyFunctionNode {
    init(_ node: _ForEachNode<some Collection, some _KeyReadableView>, depthInTree: Int) {
        self.identifier = ObjectIdentifier(node)
        self.depthInTree = depthInTree
        self.runUpdate = node.runFunction
    }
}
