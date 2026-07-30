/// A removal that has started but has to finish (e.g. exit transitions) before
/// its slot can move on to the removed lane.
///
/// The base class lives in the reconciler so transition-free builds don't
/// reference the concrete transition removal implementation and can strip it.
class _PendingRemoval {
    private static var installedType: _PendingRemoval.Type?

    static func install(_ type: _PendingRemoval.Type) {
        installedType = type
    }

    /// Starts the installed removal policy for a slot that just left the
    /// active lane. A nil result means the slot can be removed immediately.
    class func begin(
        for slot: borrowing MountContainer.Slot,
        handle: LayoutContainer.Handle?,
        tx: inout _TransactionContext
    ) -> _PendingRemoval? {
        installedType?.begin(
            for: slot,
            handle: handle,
            tx: &tx
        )
    }

    /// Whether the owning slot can move on to the removed lane.
    var isComplete: Bool { fatalError("abstract") }

    func cancel(tx: inout _TransactionContext) {
        fatalError("abstract")
    }
}
