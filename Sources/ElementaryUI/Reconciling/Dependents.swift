import BasicContainers
import SpanPreview

/// A node of the dependency graph: something others follow, something that updates in the
/// running transaction when what it follows changes, or both.
class DependencyNode {
    final var dependents = Dependents()

    init() {}

    /// Called by a followed node that changed, in the transaction that changed it.
    func invalidate(_ context: inout _TransactionContext) {}
}

/// The dependents to invalidate when a value changes.
///
/// Dependents are not retained, and each keeps the position it was added at until it is
/// removed: removing is O(1) in any order, and leaves a vacancy for the next one added.
/// Whoever adds a dependent removes it before the dependent is released; mounted nodes
/// leave that to their slot (see ``_MountContext/follow(_:with:)``).
///
/// A single dependent needs no allocation.
struct Dependents: ~Copyable {
    private enum Entry {
        case dependent(Unmanaged<DependencyNode>)
        case vacant(next: Int32)
    }

    /// Position 0.
    private var first: Unmanaged<DependencyNode>?
    /// Positions 1 and up.
    private var rest = UniqueArray<Entry>()
    /// The position of the most recent vacancy in `rest`, which leads to the one before it; 0 for none.
    private var vacancy: Int32 = 0
    private var count: Int32 = 0

    var isEmpty: Bool { count == 0 }

    /// Adds a dependent and returns its position, to remove it with.
    mutating func add(_ dependent: DependencyNode) -> Int32 {
        count &+= 1
        let dependent = Unmanaged.passUnretained(dependent)

        guard first != nil else {
            first = dependent
            return 0
        }

        let position = vacancy
        guard position != 0 else {
            rest.append(.dependent(dependent))
            return Int32(truncatingIfNeeded: rest.count)
        }

        guard case .vacant(let next) = rest[Int(position) &- 1] else {
            fatalError("vacancy is taken")
        }
        vacancy = next
        rest[Int(position) &- 1] = .dependent(dependent)
        return position
    }

    mutating func remove(at position: Int32) {
        count &-= 1
        if count == 0 {
            first = nil
            rest.removeAll()
            vacancy = 0
        } else if position == 0 {
            first = nil
        } else {
            rest[Int(position) &- 1] = .vacant(next: vacancy)
            vacancy = position
        }
    }

    /// Invalidates the dependents in the order of their positions.
    borrowing func invalidateAll(_ context: inout _TransactionContext) {
        first?._withUnsafeGuaranteedRef { $0.invalidate(&context) }

        let rest = rest.span
        for index in rest.indices {
            if case .dependent(let dependent) = rest[unchecked: index] {
                dependent._withUnsafeGuaranteedRef { $0.invalidate(&context) }
            }
        }
    }
}
