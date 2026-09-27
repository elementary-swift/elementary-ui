import BasicContainers

/// A single content source shared by every instance in a modifier body.
/// The content owns the instance nodes so content updates can reach them
/// without re-evaluating the body. Each instance's lifetime is driven by its
/// placeholder node in the body tree, which unmounts it through the content.
class PlaceholderContent: Unmountable {
    typealias InstanceID = Int

    private static let inlineID: InstanceID = -1

    private var inlineInstance: AnyReconcilable?
    // Slot indices are the instance IDs; unmounted slots are reused.
    private var additionalInstances = UniqueArray<AnyReconcilable?>()

    static func make<Value: _Mountable>(
        _ value: consuming Value
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

        for id in additionalInstances.indices where additionalInstances[id] == nil {
            additionalInstances[id] = .some(instance)
            return id
        }

        additionalInstances.append(.some(instance))
        return additionalInstances.count - 1
    }

    func unmountInstance(_ id: InstanceID, _ context: inout _CommitContext) {
        if id == Self.inlineID {
            inlineInstance.take()?.unmount(&context)
        } else {
            additionalInstances[id].take()?.unmount(&context)
        }
    }

    final func update<Value: _Mountable>(
        _ value: consuming Value,
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
        for id in additionalInstances.indices where additionalInstances[id] != nil {
            body(additionalInstances[id]!)
        }
    }

    func unmount(_ context: inout _CommitContext) {
        assert(
            inlineInstance == nil && additionalInstances.indices.allSatisfy { additionalInstances[$0] == nil },
            "Placeholder instances must be unmounted by their placeholder nodes"
        )
    }
}

/// The factory is installed once. Later mounts read the latest content value.
private final class TypedPlaceholderContent<Value: _Mountable>: PlaceholderContent {
    var value: Value

    init(_ value: consuming Value) {
        self.value = value
    }

    override func makeInstance(context: borrowing _ViewContext, ctx: inout _MountContext) -> AnyReconcilable {
        AnyReconcilable(Value._makeNode(value, context: context, ctx: &ctx))
    }
}
