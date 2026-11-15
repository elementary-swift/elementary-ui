import BasicContainers

/// A node of the dependency graph: something others depend on, something that updates in
/// the running transaction when what it depends on changes, or both.
class DependencyNode {
    fileprivate final var dependents = Dependents()

    init() {}

    /// Called by a node this one depends on when it changed, in the transaction that changed it.
    func invalidate(_ context: inout _TransactionContext) {}

    /// Makes this node depend on `source` until the returned dependency is removed.
    ///
    /// `source` retains the node until then. Mounted nodes leave the removal to their slot
    /// (see ``_MountContext/addDependency(of:on:)``).
    final func addDependency(on source: DependencyNode) -> Dependency {
        Dependency(source: source, position: source.dependents.add(self))
    }

    /// Invalidates the nodes that depend on this one, in the order of their positions.
    final func invalidateDependents(_ context: inout _TransactionContext) {
        dependents.invalidateAll(&context)
    }
}

/// One node depending on another; see ``DependencyNode/addDependency(on:)``.
struct Dependency: ~Copyable {
    fileprivate let source: DependencyNode
    fileprivate let position: Int32

    consuming func remove() {
        source.dependents.remove(at: position)
    }
}

/// The nodes that depend on a node.
///
/// Each keeps the position it was added at until it is removed: removing is O(1) in any
/// order, and leaves a vacancy for the next one added. A single dependent needs no allocation.
private struct Dependents: ~Copyable {
    /// Position 0.
    private var first: DependencyNode?
    /// Positions 1 and up; created with the second dependent.
    private var rest: Rest?

    private final class Rest {
        enum Entry {
            case dependent(DependencyNode)
            case vacant(next: Int32)
        }

        var entries = UniqueArray<Entry>()
        /// The position of the most recent vacancy, which leads to the one before it; 0 for none.
        var vacancy: Int32 = 0

        func invalidateAll(_ context: inout _TransactionContext) {
            for index in 0..<entries.count {
                if case .dependent(let dependent) = entries[index] {
                    dependent.invalidate(&context)
                }
            }
        }
    }

    /// Adds a dependent and returns its position, to remove it with.
    // inline(never) here and below: one copy for all callers (code size)
    @inline(never)
    mutating func add(_ dependent: DependencyNode) -> Int32 {
        guard first != nil else {
            first = dependent
            return 0
        }

        if rest == nil {
            rest = Rest()
        }
        let rest = rest!
        let position = rest.vacancy
        guard position != 0 else {
            rest.entries.append(.dependent(dependent))
            return Int32(truncatingIfNeeded: rest.entries.count)
        }

        guard case .vacant(let next) = rest.entries[Int(position) &- 1] else {
            fatalError("vacancy is taken")
        }
        rest.vacancy = next
        rest.entries[Int(position) &- 1] = .dependent(dependent)
        return position
    }

    @inline(never)
    mutating func remove(at position: Int32) {
        guard position != 0 else {
            first = nil
            return
        }

        let rest = rest!
        rest.entries[Int(position) &- 1] = .vacant(next: rest.vacancy)
        rest.vacancy = position
    }

    @inline(never)
    borrowing func invalidateAll(_ context: inout _TransactionContext) {
        first?.invalidate(&context)

        rest?.invalidateAll(&context)
    }
}
