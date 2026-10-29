public struct _ForEachNode<Data: RandomAccessCollection, Content: MarkupContent & _Mountable>: ~Copyable, _Reconcilable {
    private typealias Item = _TrackedContent<Data.Element, Content>

    private let container: MountContainer

    init<ID>(
        _ view: ForEach<Data, ID, Content>,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) {
        container = Self.withItems(of: view) { item in
            mountItems(keys: view.keys.span, item: item, context: context, ctx: &ctx)
        }

        ctx.appendContainer(container)
    }

    mutating func patch<ID>(
        _ view: ForEach<Data, ID, Content>,
        tx: inout _TransactionContext
    ) {
        Self.withItems(of: view) { item in
            patchItems(in: container, keys: view.keys.span, item: item, tx: &tx)
        }
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        container.unmount(&context)
    }

    /// Lends a function that builds the item for the element at an offset.
    private static func withItems<ID, R>(
        of view: ForEach<Data, ID, Content>,
        _ body: ((Int) -> Item) -> R
    ) -> R {
        let content = view.content

        // Generic subscripts go through a `read` coroutine whose frame is heap-allocated in
        // unspecialized code; contiguous storage avoids that per element.
        if let result = view.data.withContiguousStorageIfAvailable({ elements in
            body { Item(input: elements[$0], content: content) }
        }) {
            return result
        }

        let data = view.data
        return body { Item(input: data[data.index(data.startIndex, offsetBy: $0)], content: content) }
    }
}

// Generic over the item itself, so per-element work does not go through the ForEach's generics.
private func mountItems<Item: _Mountable>(
    keys: borrowing Span<_ViewKey>,
    item: (Int) -> Item,
    context: borrowing _ViewContext,
    ctx: inout _MountContext
) -> MountContainer {
    MountContainer(
        mountedKeyStorage: keys,
        context: context,
        ctx: &ctx,
        makeNode: { index, context, ctx in
            Item._makeNode(item(index), context: context, ctx: &ctx)
        }
    )
}

private func patchItems<Item: _Mountable>(
    in container: MountContainer,
    keys: borrowing Span<_ViewKey>,
    item: (Int) -> Item,
    tx: inout _TransactionContext
) {
    container.patch(
        keys: keys,
        tx: &tx,
        makeNode: { index, context, ctx in
            AnyReconcilable(Item._makeNode(item(index), context: context, ctx: &ctx))
        },
        patchNode: { index, anyNode, tx in
            anyNode.modify(as: Item._MountedNode.self) { node in
                Item._patchNode(item(index), node: &node, tx: &tx)
            }
        }
    )
}
