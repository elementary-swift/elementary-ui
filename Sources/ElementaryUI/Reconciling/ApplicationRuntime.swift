// TODO: rethink this whole API - maybe once usage of async is clearer
// TODO: there should probably be a way to "unmount" the app
// TODO: main-actor stuff very unclear at the moment, ideally not needed at all
// TODO: find a good name for this
final class ApplicationRuntime<DOMInteractor: DOM.Interactor> {
    private var rootNode: _ElementNode?
    private var scheduler: Scheduler

    init(dom: DOMInteractor) {
        self.scheduler = Scheduler(dom: dom)
        self.rootNode = nil
    }

    // generic initializers must be convenience on final classes for embedded
    // https://github.com/swiftlang/swift/issues/78150
    convenience init<RootView: View>(dom: DOMInteractor, domRoot: DOM.Node, appView rootView: consuming RootView) {
        self.init(dom: dom)

        var rootTransaction = Transaction()
        rootTransaction.disablesAnimation = true

        // TODO: defer running to a "async run" function that hosts the run loop?
        // wait until async stuff is solid for embedded wasm case
        withTransaction(rootTransaction) { [rootView, domRoot] in
            scheduler.scheduleFunction(
                .init(
                    identifier: ObjectIdentifier(self),
                    depthInTree: 0,
                    runUpdate: { [self, rootView] context in
                        self.rootNode =
                            _ElementNode(
                                root: domRoot,
                                viewContext: _ViewContext(),
                                context: &context,
                                makeChild: { [rootView] viewContext, context in
                                    AnyReconcilable(
                                        RootView._makeNode(
                                            rootView,
                                            context: viewContext,
                                            tx: &context
                                        )
                                    )
                                }
                            )
                    }
                )
            )
        }
    }

    func unmount() {
        // TODO: this should be implemented differently, current the umnount happens on next raf - which is weird
        // let's wait for the Scheduler rework (transaction + commit without rAF) and then revisit this
        guard let rootNode else { return }

        var rootTransaction = Transaction()
        rootTransaction.disablesAnimation = true

        withTransaction(rootTransaction) { [self] in
            scheduler.scheduleFunction(
                .init(
                    identifier: ObjectIdentifier(self),
                    depthInTree: 0,
                    runUpdate: { [rootNode] tx in
                        // TODO: this is sooo hacky, make this nice
                        rootNode.layoutObservers = [UnmountOnRemoval(node: AnyReconcilable(rootNode))]
                        rootNode.child.apply(.startRemoval, &tx)
                    }
                )
            )
        }

        self.rootNode = nil
    }
}

// TODO: this should not exist
private final class UnmountOnRemoval: DOMLayoutObserver {
    private var node: AnyReconcilable?

    init(node: AnyReconcilable) {
        self.node = node
    }

    func willLayoutChildren(parent: DOM.Node, context: inout _TransactionContext) {
    }

    func setLeaveStatus(_ node: DOM.Node, isLeaving: Bool, context: inout _TransactionContext) {
    }

    func didLayoutChildren(parent: DOM.Node, entries: [_ContainerLayoutPass.Entry], context: inout _CommitContext) {
        node?.unmount(&context)
        node = nil
    }

    func unmount(_ context: inout _CommitContext) {
    }
}
