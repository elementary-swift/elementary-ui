extension _HTMLTuple2: View where V0: View, V1: View {}
extension _HTMLTuple2: _Mountable where V0: _Mountable, V1: _Mountable {
    public typealias _MountedNode = _TupleNode2<V0._MountedNode, V1._MountedNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(
            V0._makeNode(view.v0, context: context, ctx: &ctx),
            V1._makeNode(view.v1, context: context, ctx: &ctx)
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        V0._patchNode(view.v0, node: &node.value.0, tx: &tx)
        V1._patchNode(view.v1, node: &node.value.1, tx: &tx)
    }
}

extension _HTMLTuple3: View where V0: View, V1: View, V2: View {}
extension _HTMLTuple3: _Mountable where V0: _Mountable, V1: _Mountable, V2: _Mountable {
    public typealias _MountedNode = _TupleNode3<V0._MountedNode, V1._MountedNode, V2._MountedNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(
            V0._makeNode(view.v0, context: context, ctx: &ctx),
            V1._makeNode(view.v1, context: context, ctx: &ctx),
            V2._makeNode(view.v2, context: context, ctx: &ctx)
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        V0._patchNode(view.v0, node: &node.value.0, tx: &tx)
        V1._patchNode(view.v1, node: &node.value.1, tx: &tx)
        V2._patchNode(view.v2, node: &node.value.2, tx: &tx)
    }
}

extension _HTMLTuple4: View where V0: View, V1: View, V2: View, V3: View {}
extension _HTMLTuple4: _Mountable where V0: _Mountable, V1: _Mountable, V2: _Mountable, V3: _Mountable {
    public typealias _MountedNode = _TupleNode4<V0._MountedNode, V1._MountedNode, V2._MountedNode, V3._MountedNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(
            V0._makeNode(view.v0, context: context, ctx: &ctx),
            V1._makeNode(view.v1, context: context, ctx: &ctx),
            V2._makeNode(view.v2, context: context, ctx: &ctx),
            V3._makeNode(view.v3, context: context, ctx: &ctx)
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        V0._patchNode(view.v0, node: &node.value.0, tx: &tx)
        V1._patchNode(view.v1, node: &node.value.1, tx: &tx)
        V2._patchNode(view.v2, node: &node.value.2, tx: &tx)
        V3._patchNode(view.v3, node: &node.value.3, tx: &tx)
    }
}

extension _HTMLTuple5: View where V0: View, V1: View, V2: View, V3: View, V4: View {}
extension _HTMLTuple5: _Mountable where V0: _Mountable, V1: _Mountable, V2: _Mountable, V3: _Mountable, V4: _Mountable {
    public typealias _MountedNode = _TupleNode5<V0._MountedNode, V1._MountedNode, V2._MountedNode, V3._MountedNode, V4._MountedNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(
            V0._makeNode(view.v0, context: context, ctx: &ctx),
            V1._makeNode(view.v1, context: context, ctx: &ctx),
            V2._makeNode(view.v2, context: context, ctx: &ctx),
            V3._makeNode(view.v3, context: context, ctx: &ctx),
            V4._makeNode(view.v4, context: context, ctx: &ctx)
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        V0._patchNode(view.v0, node: &node.value.0, tx: &tx)
        V1._patchNode(view.v1, node: &node.value.1, tx: &tx)
        V2._patchNode(view.v2, node: &node.value.2, tx: &tx)
        V3._patchNode(view.v3, node: &node.value.3, tx: &tx)
        V4._patchNode(view.v4, node: &node.value.4, tx: &tx)
    }
}

extension _HTMLTuple6: View where V0: View, V1: View, V2: View, V3: View, V4: View, V5: View {}
extension _HTMLTuple6: _Mountable where V0: _Mountable, V1: _Mountable, V2: _Mountable, V3: _Mountable, V4: _Mountable, V5: _Mountable {
    public typealias _MountedNode = _TupleNode6<
        V0._MountedNode, V1._MountedNode, V2._MountedNode, V3._MountedNode, V4._MountedNode, V5._MountedNode
    >

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(
            V0._makeNode(view.v0, context: context, ctx: &ctx),
            V1._makeNode(view.v1, context: context, ctx: &ctx),
            V2._makeNode(view.v2, context: context, ctx: &ctx),
            V3._makeNode(view.v3, context: context, ctx: &ctx),
            V4._makeNode(view.v4, context: context, ctx: &ctx),
            V5._makeNode(view.v5, context: context, ctx: &ctx)
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        V0._patchNode(view.v0, node: &node.value.0, tx: &tx)
        V1._patchNode(view.v1, node: &node.value.1, tx: &tx)
        V2._patchNode(view.v2, node: &node.value.2, tx: &tx)
        V3._patchNode(view.v3, node: &node.value.3, tx: &tx)
        V4._patchNode(view.v4, node: &node.value.4, tx: &tx)
        V5._patchNode(view.v5, node: &node.value.5, tx: &tx)
    }
}

#if !hasFeature(Embedded)
// Generic variadic tuple support using parameter packs
extension _HTMLTuple: View where repeat each Child: View {}
extension _HTMLTuple: _Mountable where repeat each Child: _Mountable {
    public typealias _MountedNode = _TupleNode<repeat (each Child)._MountedNode>

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        _MountedNode(
            repeat makeNode(
                each view.value,
                context: context,
                ctx: &ctx
            )
        )
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        // I don't think there is a way to spell this currently without warnings
        for (view, node) in repeat (each view.value, each node.value) {
            //__noop_goshDarnValuePacksAreAnnoyingAF(&view)  // this is to suppress a warning
            var mutableNode = node
            patchNode(view, node: &mutableNode, tx: &tx)
        }

        // NOTE: this doesn't work because I don't think we can pass a value pack as inout
        // repeat patchNode(
        //     each view.value,
        //     context: context,
        //     node: each &node.value,
        //     tx: &tx
        // )
    }
}

@inline(__always)
private func __noop_goshDarnValuePacksAreAnnoyingAF(_ v: inout some _Mountable) {
    // FIXME (once possible)
}

private func makeNode<V: _Mountable>(
    _ view: consuming V,
    context: borrowing _ViewContext,
    ctx: inout _MountContext
) -> V._MountedNode {
    V._makeNode(view, context: context, ctx: &ctx)
}

private func patchNode<V: _Mountable>(
    _ view: consuming V,
    node: inout V._MountedNode,
    tx: inout _TransactionContext
) {
    V._patchNode(view, node: &node, tx: &tx)
}
#endif
