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
    // A plain array: an empty one does not allocate, and its specializations
    // are much smaller than those of the noncopyable containers.
    private var entries: [any Unmountable] = []

    init() {}

    private init(entries: [any Unmountable]) {
        self.entries = entries
    }

    var isEmpty: Bool { entries.isEmpty }

    mutating func register(_ entry: any Unmountable) {
        entries.append(entry)
    }

    /// Moves the entries out, leaving this registry empty.
    mutating func take() -> UnmountRegistry {
        let entries = self.entries
        self.entries = []
        return UnmountRegistry(entries: entries)
    }

    consuming func unmount(_ context: inout _CommitContext) {
        for entry in entries {
            entry.unmount(&context)
        }
    }
}
