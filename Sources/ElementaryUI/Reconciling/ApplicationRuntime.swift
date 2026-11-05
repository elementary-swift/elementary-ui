import BasicContainers

final class ApplicationRuntime {
    private var rootNode: _ConditionalNode?
    private var rootMembers: SlotMembers?
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

                self.rootNode = scheduler.withMountContext(tx: &tx) {
                    (mountCtx: consuming _MountContext) in
                    let node = _ConditionalNode(
                        isA: true,
                        context: _ViewContext(),
                        ctx: &mountCtx,
                        makeActive: { viewContext, mountCtx in
                            RootView._makeNode(rootView, context: viewContext, ctx: &mountCtx)
                        }
                    )

                    self.rootMembers = mountCtx.mountRoot(in: domRoot)
                    return node
                }
            }
        }
    }

    func unmount() {
        scheduler.scheduleUpdate { [self] tx in
            guard var rootNode = rootNode.take() else { return }
            tx.withModifiedTransaction {
                $0.disablesAnimation = true
            } run: { tx in
                rootNode.patchWithB(tx: &tx, makeNode: { _, _ in _EmptyNode() }, updateNode: { _, _ in })

                // Break the root container/layout cycle after patch-driven removals are committed.
                tx.scheduler.addCommitAction { ctx in self.rootMembers.take()?.unmount(&ctx) }
            }
        }
        scheduler.forceRunUpdateCycleSynchronously()
    }
}
