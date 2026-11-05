import BasicContainers

/// A single content source shared by every instance in a modifier body.
/// The content owns the instance nodes so content updates can reach them
/// without re-evaluating the body. Each instance is dropped when the slot that
/// mounted its placeholder node unmounts.
class PlaceholderContent: Unmountable {
    typealias InstanceID = Int

    private static let inlineID: InstanceID = -1

    final private var inlineInstance: AnyReconcilable?
    // Slot indices are the instance IDs; unmounted slots are reused.
    final private var additionalInstances = UniqueArray<AnyReconcilable?>()

    static func make<Value: _Mountable>(
        _ value: consuming Value
    ) -> PlaceholderContent {
        TypedPlaceholderContent(value)
    }

    func makeInstance(context: borrowing _ViewContext, ctx: inout _MountContext) -> AnyReconcilable {
        fatalError("abstract")
    }

    #if !hasFeature(Embedded)
    // server rendering only renders the content value, it never mounts instances
    func _renderValue<Renderer: _HTMLRendering>(
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) {
        fatalError("abstract")
    }

    func _renderValue<Renderer: _AsyncHTMLRendering>(
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) async throws {
        fatalError("abstract")
    }
    #endif

    final func mountInstance(context: borrowing _ViewContext, ctx: inout _MountContext) {
        let instance = makeInstance(context: context, ctx: &ctx)
        if inlineInstance == nil {
            inlineInstance = .some(instance)
            ctx.registerUnmount(self)
            return
        }

        ctx.registerUnmount(AdditionalPlaceholderInstance(host: self, id: storeAdditionalInstance(instance)))
    }

    private final func storeAdditionalInstance(_ instance: consuming AnyReconcilable) -> InstanceID {
        for id in additionalInstances.indices where additionalInstances[id] == nil {
            additionalInstances[id] = .some(instance)
            return id
        }

        additionalInstances.append(.some(instance))
        return additionalInstances.count - 1
    }

    fileprivate final func dropInstance(_ id: InstanceID) {
        if id == Self.inlineID {
            inlineInstance = nil
        } else {
            additionalInstances[id] = nil
        }
    }

    final func update<Value: _Mountable>(_ value: consuming Value, tx: inout _TransactionContext) {
        unsafeDowncast(self, to: TypedPlaceholderContent<Value>.self).value = value
        patchInstances(&tx)
    }

    // Patch through the vtable so each content type does not specialize the closure.
    @inline(never)
    private final func patchInstances(_ tx: inout _TransactionContext) {
        forEachInstance { instance in patchInstance(&instance, &tx) }
    }

    func patchInstance(_ instance: inout AnyReconcilable, _ tx: inout _TransactionContext) {
        fatalError("abstract")
    }

    // Keep registry traversal out of each concrete content specialization.
    @inline(never)
    private final func forEachInstance(_ body: (inout AnyReconcilable) -> Void) {
        if inlineInstance != nil { body(&inlineInstance!) }
        for id in additionalInstances.indices where additionalInstances[id] != nil {
            body(&additionalInstances[id]!)
        }
    }

    /// Drops the inline instance; it registers the content itself.
    final func unmount(_ context: inout _CommitContext) {
        dropInstance(Self.inlineID)
    }
}

/// Drops a further instance of a content that is mounted more than once.
private final class AdditionalPlaceholderInstance: Unmountable {
    let host: PlaceholderContent
    let id: PlaceholderContent.InstanceID

    init(host: PlaceholderContent, id: PlaceholderContent.InstanceID) {
        self.host = host
        self.id = id
    }

    func unmount(_ context: inout _CommitContext) {
        host.dropInstance(id)
    }
}

/// The factory is installed once. Later mounts read the latest content value.
private class TypedPlaceholderContent<Value: _Mountable>: PlaceholderContent {
    var value: Value

    init(_ value: consuming Value) {
        self.value = value
    }

    final override func makeInstance(context: borrowing _ViewContext, ctx: inout _MountContext) -> AnyReconcilable {
        AnyReconcilable(Value._makeNode(value, context: context, ctx: &ctx))
    }

    final override func patchInstance(_ instance: inout AnyReconcilable, _ tx: inout _TransactionContext) {
        instance.modify(as: Value._MountedNode.self) { node in
            Value._patchNode(value, node: &node, tx: &tx)
        }
    }
}

#if !hasFeature(Embedded)
extension PlaceholderContent {
    static func make<Value: _Mountable & _Renderable>(
        _ value: consuming Value
    ) -> PlaceholderContent {
        RenderablePlaceholderContent(value)
    }
}

private final class RenderablePlaceholderContent<Value: _Mountable & _Renderable>: TypedPlaceholderContent<Value> {
    override func _renderValue<Renderer: _HTMLRendering>(
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) {
        Value._render(value, into: &renderer, with: context)
    }

    override func _renderValue<Renderer: _AsyncHTMLRendering>(
        into renderer: inout Renderer,
        with context: consuming _RenderingContext
    ) async throws {
        try await Value._render(value, into: &renderer, with: context)
    }
}
#endif
