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
enum SlotRegistration: ~Copyable {
    /// Runs when the slot is dropped.
    case unmountable(any Unmountable)
    /// A transition element at the slot's top level: it plays when the slot
    /// leaves, and is marked unmounted when the slot is dropped.
    case transition(_TransitionElement)
    /// A dependency of a node in the slot, removed when the slot is dropped.
    case dependency(Dependency)
}

/// A slot's registrations in order, in one exactly sized allocation (none for
/// a slot without registrations).
///
/// Nodes register after mounting their children, so running the registrations
/// in order unmounts children before their parents and siblings in order.
struct SlotRegistrations: ~Copyable {
    private var registrations: RigidArray<SlotRegistration>

    init(_ registrations: consuming RigidArray<SlotRegistration>) {
        self.registrations = registrations
    }

    borrowing func collectTransitions(into result: inout [_TransitionElement]) {
        let registrations = registrations.span
        for index in registrations.indices {
            switch registrations[unchecked: index] {
            case .transition(let element): result.append(element)
            default: break
            }
        }
    }

    consuming func unmount(_ context: inout _CommitContext) {
        registrations.consumeAll { span in
            while let registration = span.popFirst() {
                switch consume registration {
                case .unmountable(let entry):
                    entry.unmount(&context)
                case .transition(let element):
                    element.isUnmounted = true
                case .dependency(let dependency):
                    dependency.remove()
                }
            }
        }
    }
}
