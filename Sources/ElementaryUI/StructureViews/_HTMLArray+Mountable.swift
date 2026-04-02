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
        _withTemporaryAllocation(
            of: _ViewKey.self,
            capacity: self.value.count,
            { buffer in
                for index in 0..<value.count {
                    buffer.append(_ViewKey(index))
                }

                return body(buffer.span)
            }
        )
    }
}

// tiny little theft from future stdlib
@_alwaysEmitIntoClient @_transparent
func _withTemporaryAllocation<T: ~Copyable, R: ~Copyable, E: Error>(
    of type: T.Type,
    capacity: Int,
    _ body: (inout OutputSpan<T>) throws(E) -> R
) throws(E) -> R where T: ~Copyable, R: ~Copyable {
    try withUnsafeTemporaryAllocation(of: type, capacity: capacity) { (buffer) throws(E) in
        var span = OutputSpan(buffer: buffer, initializedCount: 0)
        defer {
            let initializedCount = span.finalize(for: buffer)
            span = OutputSpan()
            buffer.extracting(..<initializedCount).deinitialize()
        }

        return try body(&span)
    }
}
