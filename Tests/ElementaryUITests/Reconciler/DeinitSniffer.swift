import ElementaryUI

struct DeinitSnifferView: View {
    static func _makeNode(
        _ view: consuming DeinitSnifferView,
        context: consuming _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        _MountedNode(callback: view.callback)
    }

    static func _patchNode(
        _ view: consuming DeinitSnifferView,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.callback = view.callback
    }

    class _MountedNode: _Reconcilable {
        func apply(_ op: _ReconcileOp, _ tx: inout _TransactionContext) {}

        func collectChildren(_ ops: inout _ContainerLayoutPass, _ context: inout _CommitContext) {}

        func unmount(_ context: inout _CommitContext) {
            print("sniffer unmount")
        }

        var callback: () -> Void

        init(callback: @escaping () -> Void) {
            print("sniffer init")
            self.callback = callback
        }

        deinit {
            print("sniffer deinit")
            callback()
        }
    }

    var callback: () -> Void

    var body: Never {
        fatalError()
    }

}
