/// Something that updates in the running transaction when a value it depends on changes.
protocol Invalidateable: AnyObject {
    func invalidate(_ context: inout _TransactionContext)
}

/// The dependents to invalidate when a value changes, in registration order.
///
/// Dependents are held strongly until removed. Removal leaves a tombstone and
/// searches on from the previous removal, so removing in registration order
/// (the order slots unmount in) is O(1); tombstones are compacted at half.
struct DependencyTracker: ~Copyable {
    // A closure per dependent rather than `any Invalidateable`: an existential
    // needs a witness table per generic conformer, which is large in Embedded.
    private struct Dependent {
        /// `nil` once removed.
        var id: ObjectIdentifier?
        var invalidate: (inout _TransactionContext) -> Void

        static var removed: Dependent { Dependent(id: nil, invalidate: { _ in }) }
    }

    private var dependents: [Dependent] = []
    private var removedCount = 0
    private var searchStart = 0

    var isEmpty: Bool {
        dependents.count == removedCount
    }

    mutating func addDependency(_ dependent: some Invalidateable) {
        dependents.append(Dependent(id: ObjectIdentifier(dependent), invalidate: dependent.invalidate(_:)))
    }

    mutating func removeDependency(_ dependent: some Invalidateable) {
        remove(ObjectIdentifier(dependent))
    }

    // Not generic, so it isn't specialized for every kind of dependent (code size).
    private mutating func remove(_ id: ObjectIdentifier) {
        guard let index = index(of: id) else { return }

        dependents[index] = .removed
        removedCount &+= 1

        if removedCount &* 2 > dependents.count {
            dependents.removeAll { $0.id == nil }
            removedCount = 0
            searchStart = 0
        } else {
            searchStart = index &+ 1
        }
    }

    private func index(of id: ObjectIdentifier) -> Int? {
        dependents[searchStart...].firstIndex { $0.id == id }
            ?? dependents[..<searchStart].firstIndex { $0.id == id }
    }

    borrowing func invalidateAll(_ context: inout _TransactionContext) {
        // Iterates a copy of the storage, so dependents may register or remove others meanwhile.
        for dependent in dependents {
            dependent.invalidate(&context)
        }
    }
}
