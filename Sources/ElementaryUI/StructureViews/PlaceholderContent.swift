import BasicContainers

/// A single content source shared by every instance in a modifier body.
/// The content owns the instance nodes so content updates can reach them
/// without re-evaluating the body. Each instance's lifetime is driven by its
/// placeholder node in the body tree, which unmounts it through the content.
class PlaceholderContent: Unmountable {
    typealias InstanceID = Int

    private static let inlineID: InstanceID = 0

    private var inlineInstance: AnyReconcilable?
    private var additionalInstances = UniqueDictionary<InstanceID, AnyReconcilable>()
    private var nextAdditionalID: InstanceID = 1

    static func make<Value: _Mountable>(
        _ value: Value
    ) -> PlaceholderContent {
        TypedPlaceholderContent(value)
    }

    func makeInstance(context: borrowing _ViewContext, ctx: inout _MountContext) -> AnyReconcilable {
        fatalError("abstract")
    }

    func mountInstance(context: borrowing _ViewContext, ctx: inout _MountContext) -> InstanceID {
        let instance = makeInstance(context: context, ctx: &ctx)
        if inlineInstance == nil {
            inlineInstance = .some(instance)
            return Self.inlineID
        }

        let id = nextAdditionalID
        nextAdditionalID += 1
        additionalInstances.insertValue(instance, forKey: id)
        return id
    }

    func unmountInstance(_ id: InstanceID, _ context: inout _CommitContext) {
        if id == Self.inlineID {
            inlineInstance.take()?.unmount(&context)
        } else {
            additionalInstances.removeValue(forKey: id)?.unmount(&context)
        }
    }

    final func update<Value: _Mountable>(
        _ value: Value,
        tx: inout _TransactionContext,
        patch: (inout Value._MountedNode, inout _TransactionContext) -> Void
    ) {
        unsafeDowncast(self, to: TypedPlaceholderContent<Value>.self).value = value
        forEachInstance { instance in
            instance.modify({ node in patch(&node, &tx) })
        }
    }

    // Keep registry traversal out of each concrete content specialization.
    @inline(never)
    private func forEachInstance(_ body: (borrowing AnyReconcilable) -> Void) {
        if inlineInstance != nil { body(inlineInstance!) }
        guard !additionalInstances.isEmpty else { return }
        // Borrowing dictionary elements by index miscompiles in embedded 6.4.
        additionalInstances.withKeys { ids in
            var index = ids.startIndex
            while index != ids.endIndex {
                _ = additionalInstances.withValue(forKey: ids[index]) { body($0) }
                index = ids.index(after: index)
            }
        }
    }

    func unmount(_ context: inout _CommitContext) {
        assert(
            inlineInstance == nil && additionalInstances.isEmpty,
            "Placeholder instances must be unmounted by their placeholder nodes"
        )
    }
}

/// The factory is installed once. Later mounts read the latest content value.
private final class TypedPlaceholderContent<Value: _Mountable>: PlaceholderContent {
    var value: Value?

    init(_ value: Value) {
        self.value = value
    }

    override func makeInstance(context: borrowing _ViewContext, ctx: inout _MountContext) -> AnyReconcilable {
        precondition(value != nil)
        return AnyReconcilable(Value._makeNode(value!, context: context, ctx: &ctx))
    }

    override func unmount(_ context: inout _CommitContext) {
        super.unmount(&context)
        value = nil
    }
}
