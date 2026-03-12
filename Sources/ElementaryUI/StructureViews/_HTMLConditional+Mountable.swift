extension _HTMLConditional: View where TrueContent: View, FalseContent: View {}
extension _HTMLConditional: _Mountable where TrueContent: _Mountable, FalseContent: _Mountable {
    public typealias _MountedNode = _ConditionalNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) -> _MountedNode {
        switch view.value {
        case let .trueContent(content):
            let aRoot = MountRoot.materialized(
                seedContext: context,
                ctx: &ctx,
                create: { context, ctx in
                    AnyReconcilable(TrueContent._makeNode(content, context: context, ctx: &ctx))
                }
            )
            return .init(aRoot: aRoot, context: context)
        case let .falseContent(content):
            let bRoot = MountRoot.materialized(
                seedContext: context,
                ctx: &ctx,
                create: { context, ctx in
                    AnyReconcilable(FalseContent._makeNode(content, context: context, ctx: &ctx))
                }
            )
            return .init(bRoot: bRoot, context: context)
        }
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        switch view.value {
        case let .trueContent(content):
            node.patchWithA(
                tx: &tx,
                makeNode: { c, ctx in TrueContent._makeNode(content, context: c, ctx: &ctx) },
                updateNode: { node, tx in TrueContent._patchNode(content, node: &node, tx: &tx) }
            )
        case let .falseContent(content):
            node.patchWithB(
                tx: &tx,
                makeNode: { c, ctx in FalseContent._makeNode(content, context: c, ctx: &ctx) },
                updateNode: { node, tx in FalseContent._patchNode(content, node: &node, tx: &tx) }
            )
        }
    }
}
