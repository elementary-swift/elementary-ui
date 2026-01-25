// TODO: rethink this whole API - maybe once usage of async is clearer
// TODO: main-actor stuff very unclear at the moment, ideally not needed at all
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

        scheduler.scheduleUpdate { [self, rootView] tx in
            tx.withModifiedTransaction {
                $0.disablesAnimation = true
            } run: { tx in
                self.rootNode =
                    _ElementNode(
                        root: domRoot,
                        viewContext: _ViewContext(),
                        tx: &tx,
                        makeChild: { [rootView] viewContext, tx in
                            AnyReconcilable(
                                RootView._makeNode(
                                    rootView,
                                    context: viewContext,
                                    tx: &tx
                                )
                            )
                        }
                    )
            }
        }
    }

    func unmount() {
        guard let rootNode else { return }

        scheduler.scheduleUpdate { [rootNode] tx in
            tx.withModifiedTransaction {
                $0.disablesAnimation = true
            } run: { tx in
                tx.scheduler.addPlacementAction { ctx in
                    rootNode.unmount(&ctx)
                }

                rootNode.child.apply(.startRemoval, &tx)
            }
        }

        self.rootNode = nil
    }
}
