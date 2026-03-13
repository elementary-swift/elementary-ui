extension Optional: View where Wrapped: View {}
extension Optional: _Mountable where Wrapped: _Mountable {
    public typealias _MountedNode = _ConditionalNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        let transaction = context.mountRoot.inheritedTransaction()
        switch view {
        case let .some(view):
            let root = MountRoot(
                mountedFrom: context,
                transaction: transaction,
                ctx: &ctx,
                create: { c, mountCtx in
                    AnyReconcilable(Wrapped._makeNode(view, context: c, ctx: &mountCtx))
                }
            )
            return .init(isA: true, root: root, context: context, ctx: &ctx)
        case .none:
            let root = MountRoot(
                mountedFrom: context,
                transaction: transaction,
                ctx: &ctx,
                create: { c, mountCtx in
                    AnyReconcilable(EmptyHTML._makeNode(EmptyHTML(), context: c, ctx: &mountCtx))
                }
            )
            return .init(isA: false, root: root, context: context, ctx: &ctx)
        }
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        switch view {
        case let .some(view):
            node.patchWithA(
                tx: &tx,
                makeNode: { c, ctx in Wrapped._makeNode(view, context: c, ctx: &ctx) },
                updateNode: { node, tx in Wrapped._patchNode(view, node: &node, tx: &tx) }
            )
        case .none:
            node.patchWithB(
                tx: &tx,
                makeNode: { _, _ in _EmptyNode() },
                updateNode: { _, _ in }
            )
        }
    }
}
