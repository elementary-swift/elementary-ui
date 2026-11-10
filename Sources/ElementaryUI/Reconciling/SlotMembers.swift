import BasicContainers
import SpanPreview

/// Something mounted that has work to do when its slot is dropped: release
/// a listener, break a reference cycle, stop an animation. Everything else in
/// a dropped slot is simply released.
///
/// In Embedded Swift, a generic conformer's witness table is specialized as
/// serialized, which duplicates everything its `unmount` reaches. Generic types
/// with heavy `unmount` work conform through a non-generic base (code size).
protocol Unmountable: AnyObject {
    func unmount(_ context: inout _CommitContext)
}

/// Something registered with the slot that owns it while the slot mounts.
enum SlotMember {
    /// Runs when the slot is dropped.
    case unmountable(any Unmountable)
    /// A transition element at the slot's top level: it plays when the slot
    /// leaves, and is marked unmounted when the slot is dropped.
    case transition(_TransitionElement)
    /// A node of the slot follows `source`, at `position` among its dependents,
    /// until the slot is dropped.
    case following(source: DependencyNode, position: Int32)
}

/// A slot's members in registration order, in one exactly sized allocation
/// (none for a slot without members).
///
/// Nodes register after mounting their children, so running the members in
/// order unmounts children before their parents and siblings in order.
struct SlotMembers: ~Copyable {
    private var members: RigidArray<SlotMember>

    init(_ members: consuming RigidArray<SlotMember>) {
        self.members = members
    }

    borrowing func collectTransitions(into result: inout [_TransitionElement]) {
        let members = members.span
        for index in members.indices {
            if case .transition(let element) = members[unchecked: index] {
                result.append(element)
            }
        }
    }

    consuming func unmount(_ context: inout _CommitContext) {
        members.consumeAll { span in
            while let member = span.popFirst() {
                switch member {
                case .unmountable(let entry):
                    entry.unmount(&context)
                case .transition(let element):
                    element.isUnmounted = true
                case .following(let source, let position):
                    source.dependents.remove(at: position)
                }
            }
        }
    }
}
