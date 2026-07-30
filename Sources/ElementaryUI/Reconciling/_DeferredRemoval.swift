/// An optional hook for features that keep removed slots alive.
///
/// The base class lives in the reconciler so transition-free builds don't
/// reference the concrete transition removal implementation.
class _DeferredRemoval {
    private static var type: _DeferredRemoval.Type?

    static func install(type: _DeferredRemoval.Type) {
        self.type = type
    }

    class func begin(
        mounted: borrowing MountContainer.Slot.Mounted,
        handle: LayoutContainer.Handle?,
        tx: inout _TransactionContext
    ) -> _DeferredRemoval? {
        type?.begin(mounted: mounted, handle: handle, tx: &tx)
    }

    var isReady: Bool { fatalError("abstract") }

    func cancel(tx: inout _TransactionContext) {
        fatalError("abstract")
    }
}
