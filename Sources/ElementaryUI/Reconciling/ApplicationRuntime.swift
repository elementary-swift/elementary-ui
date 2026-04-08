import BasicContainers

final class ApplicationRuntime<DOMInteractor: DOM.Interactor> {
    private var rootNode: _ConditionalNode?
    private var scheduler: Scheduler

    init(dom: DOMInteractor) {
        self.scheduler = Scheduler(dom: dom)
    }

    // generic initializers must be convenience on final classes for embedded
    // https://github.com/swiftlang/swift/issues/78150
    convenience init<RootView: View>(dom: DOMInteractor, domRoot: DOM.Node, appView rootView: consuming RootView) {
        self.init(dom: dom)

        scheduler.scheduleUpdate { [self, rootView] tx in
            tx.withModifiedTransaction {
                $0.disablesAnimation = true
            } run: { tx in

                tx.scheduler.addCommitAction { [self, transaction = tx.transaction, rootView] ctx in
                    self.rootNode =
                        ctx.withMountContext(transaction: transaction) {
                            (mountCtx: consuming _MountContext) in
                            let node = _ConditionalNode(
                                isA: true,
                                context: _ViewContext(),
                                ctx: &mountCtx,
                                makeActive: { viewContext, mountCtx in
                                    RootView._makeNode(rootView, context: viewContext, ctx: &mountCtx)
                                }
                            )

                            _ = mountCtx.mountInDOMNode(domRoot, observers: [])
                            return node
                        }
                }
            }
        }
    }

    func unmount() {
        guard var rootNode = self.rootNode.take() else { return }

        scheduler.scheduleUpdate { tx in
            tx.withModifiedTransaction {
                $0.disablesAnimation = true
            } run: { tx in
                rootNode.patchWithB(tx: &tx, makeNode: { _, _ in _EmptyNode() }, updateNode: { _, _ in })

                // Break the root container/layout cycle after patch-driven removals are committed.
                tx.scheduler.addCommitAction { ctx in rootNode.container.unmount(&ctx) }
            }
        }
    }
}
