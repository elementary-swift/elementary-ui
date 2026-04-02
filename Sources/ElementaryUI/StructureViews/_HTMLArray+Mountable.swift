import BasicContainers

extension _HTMLArray: _Mountable, View where Element: View {
    public typealias _MountedNode = _KeyedNode

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        view.withKeys { keys in
            _MountedNode(
                keys: keys,
                context: context,
                ctx: &ctx,
                makeNode: { index, context, ctx in
                    Element._makeNode(view.value[index], context: context, ctx: &ctx)
                }
            )
        }
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        view.withKeys { keys in
            node.patch(
                keys,
                context: &tx,
                makeNode: { index, context, ctx in
                    AnyReconcilable(
                        Element._makeNode(view.value[index], context: context, ctx: &ctx)
                    )
                },
                patchNode: { index, anyNode, tx in
                    anyNode.modify(as: Element._MountedNode.self) { node in
                        Element._patchNode(view.value[index], node: &node, tx: &tx)
                    }
                }
            )
        }
    }

    private func withKeys<R: ~Copyable>(_ body: (borrowing Span<_ViewKey>) -> R) -> R {
        // TODO: make this nicer and less unsafe
        withUnsafeTemporaryAllocation(
            of: _ViewKey.self,
            capacity: self.value.count,
            { buffer in
                for index in 0..<value.count {
                    buffer[index] = _ViewKey(index)
                }

                return body(buffer.span)
            }
        )
    }
}
