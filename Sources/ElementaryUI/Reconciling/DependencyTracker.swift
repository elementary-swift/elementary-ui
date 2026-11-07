/// Something that updates in the running transaction when a value it depends on changes.
// A base class rather than a protocol: in Embedded, an existential needs a witness
// table per generic conformer, and closures need a context per registration.
public class _Invalidateable {
    func invalidate(_ context: inout _TransactionContext) {
        fatalError("abstract")
    }
}

/// The dependents to invalidate when a value changes, in registration order.
///
/// Dependents are held strongly until removed. Removal leaves a tombstone and
/// searches on from the previous removal, so removing in registration order
/// (the order slots unmount in) is O(1); tombstones are compacted at half.
struct DependencyTracker: ~Copyable {
    /// `nil` once removed.
    private var dependents: [_Invalidateable?] = []
    private var removedCount = 0
    private var searchStart = 0

    var isEmpty: Bool {
        dependents.count == removedCount
    }

    mutating func addDependency(_ dependent: _Invalidateable) {
        dependents.append(dependent)
    }

    mutating func removeDependency(_ dependent: _Invalidateable) {
        guard let index = index(of: dependent) else { return }

        dependents[index] = nil
        removedCount &+= 1

        if removedCount &* 2 > dependents.count {
            dependents.removeAll { $0 == nil }
            removedCount = 0
            searchStart = 0
        } else {
            searchStart = index &+ 1
        }
    }

    private func index(of dependent: _Invalidateable) -> Int? {
        dependents[searchStart...].firstIndex { $0 === dependent }
            ?? dependents[..<searchStart].firstIndex { $0 === dependent }
    }

    borrowing func invalidateAll(_ context: inout _TransactionContext) {
        // Iterates a copy of the storage, so dependents may register or remove others meanwhile.
        for dependent in dependents {
            dependent?.invalidate(&context)
        }
    }
}
