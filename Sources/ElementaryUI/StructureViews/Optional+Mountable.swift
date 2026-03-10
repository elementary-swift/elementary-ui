extension Optional: View where Wrapped: View {}
extension Optional: _Mountable where Wrapped: _Mountable {
    public typealias _MountedNode = _ConditionalNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        switch view {
        case let .some(view):
            return .init(a: Wrapped._makeNode(view, context: context, tx: &tx), context: context)
        case .none:
            return .init(b: _EmptyNode(), context: context)
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
                makeNode: { c, tx in Wrapped._makeNode(view, context: c, tx: &tx) },
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
