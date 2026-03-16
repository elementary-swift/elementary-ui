// TODO: either get rid of this protocol entirely, or turn it into a dedicated
// mount lifecycle owner type.
public protocol _Reconcilable {
    consuming func unmount(_ context: inout _CommitContext)
}

struct AnyReconcilable {
    class _Box {
        func unmount(_ context: inout _CommitContext) {}
    }

    final class _TypedBox<R: _Reconcilable>: _Box {
        var node: R

        init(_ node: consuming R) { self.node = node }

        override func unmount(_ context: inout _CommitContext) {
            node.unmount(&context)
        }
    }

    private var box: _Box

    init<R: _Reconcilable>(_ node: R) {
        self.box = _TypedBox(node)

    }
    func unmount(_ context: inout _CommitContext) {
        box.unmount(&context)
    }

    // TODO: make this mutating to prepare for ~Copyable all the way
    func modify<R: _Reconcilable>(as type: R.Type = R.self, _ body: (inout R) -> Void) {
        let box = unsafeDowncast(self.box, to: _TypedBox<R>.self)
        body(&box.node)
    }
}
