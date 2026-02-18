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
        tx: inout _TransactionContext
    ) {
        self.data = data
        self.contentBuilder = contentBuilder
        self.context = copy context
        self.depthInTree = context.functionDepth
        self.asFunctionNode = AnyFunctionNode(self)

        tx.addFunction(asFunctionNode)
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

        let (views, session) = withReactiveTrackingSession {
            data.map { value in
                contentBuilder(value)
            }
        } onWillSet: { [scheduler = tx.scheduler, asFunctionNode = asFunctionNode!] in
            scheduler.invalidateFunction(asFunctionNode)
        }

        self.trackingSession = session

        if keyedNode == nil {
            keyedNode = _KeyedNode(
                views.map { view in
                    (
                        key: view._key,
                        node: Content.Value._makeNode(view._value, context: context, tx: &tx)
                    )
                },
                context: context
            )
            return
        }

        keyedNode!.patch(
            views.map { $0._key },
            context: &tx,
            as: Content.Value._MountedNode.self,
        ) { index, node, context, tx in
            if node == nil {
                node = Content.Value._makeNode(views[index]._value, context: context, tx: &tx)
            } else {
                Content.Value._patchNode(views[index]._value, node: node!, tx: &tx)
            }
        }
    }

    public func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {
        keyedNode?.collectChildren(&ops, &context)
    }

    public func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {
        keyedNode?.apply(op, &tx)
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
