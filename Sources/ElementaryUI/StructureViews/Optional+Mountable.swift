extension Optional: View where Wrapped: View {}
extension Optional: _Mountable where Wrapped: _Mountable {
    public typealias _MountedNode = _ConditionalNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) -> _MountedNode {
        switch view {
        case let .some(view):
            let aRoot = MountRoot.materialized(
                seedContext: context,
                ctx: &ctx,
                create: { context, ctx in
                    AnyReconcilable(Wrapped._makeNode(view, context: context, ctx: &ctx))
                }
            )
            return .init(aRoot: aRoot, context: context)
        case .none:
            let bRoot = MountRoot.materialized(
                seedContext: context,
                ctx: &ctx,
                create: { _, _ in AnyReconcilable(_EmptyNode()) }
            )
            return .init(bRoot: bRoot, context: context)
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
