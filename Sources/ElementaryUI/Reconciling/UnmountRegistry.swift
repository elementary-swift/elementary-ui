import BasicContainers

/// Something mounted that has to do work, break a reference cycle, or just
/// stay alive until its subtree is removed. Registered on the mount context;
/// everything else in a removed subtree is simply dropped.
///
/// In Embedded Swift, a generic conformer's witness table is specialized as
/// serialized, which duplicates everything its `unmount` reaches. Generic types
/// with heavy `unmount` work conform through a non-generic base (code size).
protocol Unmountable: AnyObject {
    func unmount(_ context: inout _CommitContext)
}

extension Unmountable {
    func unmount(_ context: inout _CommitContext) {}
}

/// The unmount work of one structural slot (or of the application root), in
/// registration order.
///
/// Nodes register after mounting their children, so running the entries in
/// order unmounts children before their parents and siblings in order.
struct UnmountRegistry: ~Copyable {
    // Empty until something registers, so most slots never allocate.
    private var entries = UniqueArray<any Unmountable>()

    init() {}

    var isEmpty: Bool { entries.isEmpty }

    mutating func register(_ entry: any Unmountable) {
        entries.append(entry)
    }

    /// Moves the entries out, leaving this registry empty.
    mutating func take() -> UnmountRegistry {
        var taken = UnmountRegistry()
        swap(&taken.entries, &entries)
        return taken
    }

    consuming func unmount(_ context: inout _CommitContext) {
        entries.consumeAll { span in
            while let entry = span.popFirst() {
                entry.unmount(&context)
            }
        }
    }
}
