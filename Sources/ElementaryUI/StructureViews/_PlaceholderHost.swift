import BasicContainers

/// A single content source shared by every occurrence in a modifier body.
/// The host owns the occurrence nodes so content updates can reach them
/// without re-evaluating the body. Each occurrence's lifetime is driven by its
/// placeholder node in the body tree, which unmounts it through the host.
class _PlaceholderHost: Unmountable {
    typealias OccurrenceID = Int

    private static let inlineID: OccurrenceID = 0

    private var first: AnyReconcilable?
    private var additional = UniqueDictionary<OccurrenceID, AnyReconcilable>()
    private var nextAdditionalID: OccurrenceID = 1

    static func make<Value: _Mountable>(
        _ value: Value
    ) -> _PlaceholderHost {
        _TypedPlaceholderHost(value)
    }

    func makeOccurrence(context: borrowing _ViewContext, ctx: inout _MountContext) -> AnyReconcilable {
        fatalError("abstract")
    }

    func mount(context: borrowing _ViewContext, ctx: inout _MountContext) -> OccurrenceID {
        let occurrence = makeOccurrence(context: context, ctx: &ctx)
        if first == nil {
            first = .some(occurrence)
            return Self.inlineID
        }

        let id = nextAdditionalID
        nextAdditionalID += 1
        additional.insertValue(occurrence, forKey: id)
        return id
    }

    func unmountOccurrence(_ id: OccurrenceID, _ context: inout _CommitContext) {
        if id == Self.inlineID {
            first.take()?.unmount(&context)
        } else {
            additional.removeValue(forKey: id)?.unmount(&context)
        }
    }

    final func update<Value: _Mountable>(
        _ value: Value,
        tx: inout _TransactionContext,
        patch: (inout Value._MountedNode, inout _TransactionContext) -> Void
    ) {
        unsafeDowncast(self, to: _TypedPlaceholderHost<Value>.self).value = value
        forEachOccurrence { occurrence in
            occurrence.modify({ node in patch(&node, &tx) })
        }
    }

    // Keep registry traversal out of each concrete content specialization.
    @inline(never)
    private func forEachOccurrence(_ body: (borrowing AnyReconcilable) -> Void) {
        if first != nil { body(first!) }
        guard !additional.isEmpty else { return }
        // Borrowing dictionary elements by index miscompiles in embedded 6.4.
        additional.withKeys { ids in
            var index = ids.startIndex
            while index != ids.endIndex {
                _ = additional.withValue(forKey: ids[index]) { body($0) }
                index = ids.index(after: index)
            }
        }
    }

    func unmount(_ context: inout _CommitContext) {
        assert(first == nil && additional.isEmpty, "Placeholder occurrences must be unmounted by their placeholder nodes")
    }
}

/// The factory is installed once. Later mounts read the latest content value.
private final class _TypedPlaceholderHost<Value: _Mountable>: _PlaceholderHost {
    var value: Value?

    init(_ value: Value) {
        self.value = value
    }

    override func makeOccurrence(context: borrowing _ViewContext, ctx: inout _MountContext) -> AnyReconcilable {
        precondition(value != nil)
        return AnyReconcilable(Value._makeNode(value!, context: context, ctx: &ctx))
    }

    override func unmount(_ context: inout _CommitContext) {
        super.unmount(&context)
        value = nil
    }
}
