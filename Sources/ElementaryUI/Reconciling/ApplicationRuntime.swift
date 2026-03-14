// TODO: rethink this whole API - maybe once usage of async is clearer
// TODO: main-actor stuff very unclear at the moment, ideally not needed at all
final class ApplicationRuntime<DOMInteractor: DOM.Interactor> {
    private var rootChild: AnyReconcilable?
    private var rootContainer: LayoutContainer?
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
                let rootViewContext = _ViewContext()
                let mountTransaction = tx.transaction

                tx.scheduler.addCommitAction { [self, rootView, rootViewContext] ctx in
                    var mountContext = _MountContext(ctx: ctx, transaction: mountTransaction)
                    let child = AnyReconcilable(
                        RootView._makeNode(rootView, context: rootViewContext, ctx: &mountContext)
                    )
                    let layoutNodes = mountContext.takeLayoutNodes()

                    let container = LayoutContainer(
                        domNode: domRoot,
                        scheduler: ctx.scheduler,
                        layoutNodes: layoutNodes,
                        layoutObservers: []
                    )
                    container.mountInitial(&ctx)

                    self.rootChild = child
                    self.rootContainer = container
                }
            }
        }
    }

    func unmount() {
        guard let rootChild, let rootContainer else { return }

        scheduler.scheduleUpdate { [rootChild, rootContainer] tx in
            tx.withModifiedTransaction {
                $0.disablesAnimation = true
            } run: { tx in
                tx.scheduler.addPlacementAction { ctx in
                    rootContainer.removeAllChildren(&ctx)
                    rootChild.unmount(&ctx)
                }
            }
        }

        self.rootChild = nil
        self.rootContainer = nil
    }
}
