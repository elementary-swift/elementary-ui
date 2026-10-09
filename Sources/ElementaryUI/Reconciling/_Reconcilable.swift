import Builtin
import ContainersPreview

public protocol _Reconcilable: ~Copyable {
    consuming func unmount(_ context: inout _CommitContext)
}

// Holds either R directly or a UniqueBox<R>, as selected by _ReconcilableLayout.
// This buffer owns no cleanup; the matching witness handles its hidden value.
@_rawLayout(likeArrayOf: _TextNode, count: 1)
private struct _ReconcilableStorage: ~Copyable {
    // Only the layout initializer supplies values here: a checked inline R or
    // a one-pointer UniqueBox<R>. Stored must fit and be bitwise-takable.
    @inline(__always)
    init<Stored: ~Copyable>(storing value: consuming Stored) {
        let address = UnsafeMutableRawPointer(Builtin.addressOfRawLayout(self))
        address.bindMemory(to: Stored.self, capacity: 1).initialize(to: value)
    }

    // The address is valid only during body. The caller must preserve the
    // payload's binding and ownership, and must not let the pointer escape.
    @inline(__always)
    borrowing func withUnsafeMutableAddress<Result: ~Copyable>(
        _ body: (UnsafeMutableRawPointer) -> Result
    ) -> Result {
        body(UnsafeMutableRawPointer(Builtin.addressOfRawLayout(self)))
    }
}

@inline(__always)
private func _fitsInline<R: ~Copyable>(_: R.Type) -> Bool {
    MemoryLayout<R>.size <= MemoryLayout<_ReconcilableStorage>.size
        && MemoryLayout<R>.alignment <= MemoryLayout<_ReconcilableStorage>.alignment
        && Bool(Builtin.isbitwisetakable(R.self))
}

// Avoid the out-of-line generic UnsafeMutablePointer.move entry point for
// the one-word UniqueBox wrapper. The pointer must address one initialized
// value; this typed move leaves that memory uninitialized.
@inline(__always)
private func _unsafeTake<R: ~Copyable>(_ pointer: UnsafeMutablePointer<R>) -> R {
    Builtin.take(pointer._rawValue)
}

// Used through metatypes only: no instances or stored closure contexts.
private class _ReconcilableWitness {
    class func destroy(_ storage: UnsafeMutableRawPointer) { fatalError("abstract") }
    class func unmount(_ storage: UnsafeMutableRawPointer, _ context: inout _CommitContext) {
        fatalError("abstract")
    }
}

private final class _InlineReconcilableWitness<R: _Reconcilable & ~Copyable>: _ReconcilableWitness {
    override class func destroy(_ storage: UnsafeMutableRawPointer) {
        storage.assumingMemoryBound(to: R.self).deinitialize(count: 1)
    }

    override class func unmount(_ storage: UnsafeMutableRawPointer, _ context: inout _CommitContext) {
        _unsafeTake(storage.assumingMemoryBound(to: R.self)).unmount(&context)
    }
}

private final class _HeapReconcilableWitness<R: _Reconcilable & ~Copyable>: _ReconcilableWitness {
    override class func destroy(_ storage: UnsafeMutableRawPointer) {
        _ = _unsafeTake(storage.assumingMemoryBound(to: UniqueBox<R>.self))
    }

    override class func unmount(_ storage: UnsafeMutableRawPointer, _ context: inout _CommitContext) {
        _unsafeTake(storage.assumingMemoryBound(to: UniqueBox<R>.self)).consume().unmount(&context)
    }
}

// Selects the representation and its matching lifecycle operations together.
// Raw bytes relocate without a typed move, so only bitwise-takable values may
// live directly in the buffer. Other values stay at a stable address in a box.
private struct _ReconcilableLayout: ~Copyable {
    var storage: _ReconcilableStorage
    let witness: _ReconcilableWitness.Type

    @inline(__always)
    init<R: _Reconcilable & ~Copyable>(_ value: consuming R) {
        if _fitsInline(R.self) {
            storage = _ReconcilableStorage(storing: value)
            witness = _InlineReconcilableWitness<R>.self
        } else {
            storage = _ReconcilableStorage(storing: UniqueBox(value))
            witness = _HeapReconcilableWitness<R>.self
        }
    }
}

// A raw-layout owner can discard itself after consuming its hidden payload.
// A Swift stored raw-layout property would prevent discard in Swift 6.4.
// Embedded Swift additionally requires this owner to have a frozen layout.
@usableFromInline
@frozen
@_rawLayout(like: _ReconcilableLayout)
struct AnyReconcilable: ~Copyable {
    @inline(__always)
    init<R: _Reconcilable & ~Copyable>(_ value: consuming R) {
        let address = UnsafeMutableRawPointer(Builtin.addressOfRawLayout(self))
        address.bindMemory(to: _ReconcilableLayout.self, capacity: 1)
            .initialize(to: _ReconcilableLayout(value))
    }

    // Projects the hidden layout and keeps the payload address scoped to body.
    // The caller must not escape the pointer, change its binding, or access the
    // payload after consuming/destroying it. Mutation requires exclusive ownership.
    @inline(__always)
    private borrowing func withUnsafeMutableStorage<Result: ~Copyable>(
        _ body: (UnsafeMutableRawPointer, _ReconcilableWitness.Type) -> Result
    ) -> Result {
        let layout = UnsafeMutableRawPointer(Builtin.addressOfRawLayout(self))
            .assumingMemoryBound(to: _ReconcilableLayout.self)
        let witness = layout.pointee.witness
        return layout.pointee.storage.withUnsafeMutableAddress { body($0, witness) }
    }

    deinit {
        withUnsafeMutableStorage { storage, witness in witness.destroy(storage) }
    }

    // Precondition: R is exactly the type passed to init.
    @inline(__always)
    mutating func modify<R: _Reconcilable & ~Copyable>(as type: R.Type = R.self, _ body: (inout R) -> Void) {
        withUnsafeMutableStorage { storage, witness in
            if _fitsInline(R.self) {
                precondition(
                    witness == _InlineReconcilableWitness<R>.self,
                    "Incorrect erased node type"
                )
                body(&storage.assumingMemoryBound(to: R.self).pointee)
            } else {
                precondition(
                    witness == _HeapReconcilableWitness<R>.self,
                    "Incorrect erased node type"
                )
                body(&storage.assumingMemoryBound(to: UniqueBox<R>.self).pointee.value)
            }
        }
    }

    consuming func unmount(_ context: inout _CommitContext) {
        withUnsafeMutableStorage { storage, witness in witness.unmount(storage, &context) }
        discard self  // this is load-bearing
    }
}
