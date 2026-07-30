/// An optional hook for features that keep removed slots alive.
///
/// The base class lives in the reconciler so transition-free builds don't
/// reference the concrete transition removal implementation.
class _DeferredRemoval {
    private static var installedType: _DeferredRemoval.Type?

    static func install(_ type: _DeferredRemoval.Type) {
        installedType = type
    }

    /// Starts the installed removal policy. A nil result means the slot can be
    /// removed immediately.
    class func startIfNeeded(
        for mounted: borrowing MountContainer.Slot.Mounted,
        handle: LayoutContainer.Handle?,
        tx: inout _TransactionContext
    ) -> _DeferredRemoval? {
        installedType?.startIfNeeded(
            for: mounted,
            handle: handle,
            tx: &tx
        )
    }

    /// Whether the owning slot can leave the deferred-removal lane.
    var isReadyForRemoval: Bool { fatalError("abstract") }

    func cancel(tx: inout _TransactionContext) {
        fatalError("abstract")
    }
}
