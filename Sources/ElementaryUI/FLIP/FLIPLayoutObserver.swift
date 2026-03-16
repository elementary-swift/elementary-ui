final class FLIPLayoutObserver: DOMLayoutObserver {
    private var childNodes: [DOM.Node] = []
    private var animateContainerSize: Bool

    init(animateContainerSize: Bool) {
        self.animateContainerSize = animateContainerSize
    }

    func update(animateContainerSize: Bool) {
        self.animateContainerSize = animateContainerSize
    }

    func willLayoutChildren(parent: DOM.Node, context: inout _TransactionContext) {
        guard !context.transaction.shouldSkipFLIP else {
            logTrace("skipping FLIP for children of parent \(parent) because transaction should skip FLIP")
            return
        }

        context.scheduler.flip.scheduleAnimationOf(childNodes, inParent: parent, context: &context)

        if animateContainerSize {
            context.scheduler.flip.scheduleAnimationOf(parent, context: &context)
        }
    }

    func setLeaveStatus(_ node: DOM.Node, isLeaving: Bool, context: inout _TransactionContext) {
        logTrace("setting leave status for node \(node) to \(isLeaving)")
        if isLeaving {
            context.scheduler.flip.markAsLeaving(node)
        } else {
            context.scheduler.flip.markAsReentering(node)
        }
    }

    func didLayoutChildren(parent: DOM.Node, entries: [LayoutPass.Entry], context: inout _CommitContext) {
        childNodes.removeAll(keepingCapacity: true)
        childNodes.reserveCapacity(entries.count)

        for entry in entries where entry.type == .element {
            switch entry.op {
            case .added, .unchanged, .moved:
                childNodes.append(entry.reference)
            case .removed:
                context.scheduler.flip.markAsRemoved(entry.reference)
            }
        }
    }

    func unmount(_ context: inout _CommitContext) {
        for node in childNodes {
            context.scheduler.flip.markAsRemoved(node)
        }
        childNodes = []
    }
}

private extension Transaction {
    var shouldSkipFLIP: Bool {
        // HACK: this is a bit brittle, but a transition removal is currently scheduled as an animation callback
        // and this is a way to identify them... not sure if this will bite us one day
        disablesAnimation && animation == nil
    }
}
