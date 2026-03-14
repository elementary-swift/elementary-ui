extension Optional: View where Wrapped: View {}
extension Optional: _Mountable where Wrapped: _Mountable {
    public typealias _MountedNode = _ConditionalNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        switch view {
        case let .some(view):
            return .init(
                isA: true,
                context: context,
                ctx: &ctx,
                makeActive: { c, mountCtx in
                    Wrapped._makeNode(view, context: c, ctx: &mountCtx)
                }
            )
        case .none:
            return .init(
                isA: false,
                context: context,
                ctx: &ctx,
                makeActive: { c, mountCtx in
                    EmptyHTML._makeNode(EmptyHTML(), context: c, ctx: &mountCtx)
                }
            )
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
