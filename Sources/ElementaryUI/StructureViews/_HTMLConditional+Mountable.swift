extension _HTMLConditional: View where TrueContent: View, FalseContent: View {}
extension _HTMLConditional: _Mountable where TrueContent: _Mountable, FalseContent: _Mountable {
    public typealias _MountedNode = _ConditionalNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        let transaction = context.mountRoot.inheritedTransaction()
        switch view.value {
        case let .trueContent(content):
            let root = MountRoot(
                mountedFrom: context,
                transaction: transaction,
                ctx: &ctx,
                create: { c, mountCtx in
                    AnyReconcilable(TrueContent._makeNode(content, context: c, ctx: &mountCtx))
                }
            )
            return .init(isA: true, root: root, context: context, ctx: &ctx)
        case let .falseContent(content):
            let root = MountRoot(
                mountedFrom: context,
                transaction: transaction,
                ctx: &ctx,
                create: { c, mountCtx in
                    AnyReconcilable(FalseContent._makeNode(content, context: c, ctx: &mountCtx))
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
