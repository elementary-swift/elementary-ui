final class FLIPLayoutObserver: DOMLayoutObserver {
    private var activeChildNodes: [DOM.Node] = []
    private var outOfBandLeavingNodes: [DOM.Node] = []
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

        var scheduledNodes = activeChildNodes
        if !outOfBandLeavingNodes.isEmpty {
            scheduledNodes.reserveCapacity(activeChildNodes.count + outOfBandLeavingNodes.count)
            for leaving in outOfBandLeavingNodes where !activeChildNodes.contains(where: { $0 == leaving }) {
                scheduledNodes.append(leaving)
            }
        }

        context.scheduler.flip.scheduleAnimationOf(scheduledNodes, inParent: parent, context: &context)

        if animateContainerSize {
            context.scheduler.flip.scheduleAnimationOf(parent, context: &context)
        }
    }

    func setLeaveStatus(_ node: DOM.Node, isLeaving: Bool, context: inout _TransactionContext) {
        logTrace("setting leave status for node \(node) to \(isLeaving)")
        if isLeaving {
            if !outOfBandLeavingNodes.contains(where: { $0 == node }) {
                outOfBandLeavingNodes.append(node)
            }
            context.scheduler.flip.markAsLeaving(node, context: &context)
        } else {
            outOfBandLeavingNodes.removeAll { $0 == node }
            context.scheduler.flip.markAsReentering(node, context: &context)
        }
    }

    func didLayoutChildren(parent: DOM.Node, entries: borrowing Span<LayoutPass.Entry>, context: inout _CommitContext) {
        activeChildNodes.removeAll(keepingCapacity: true)
        activeChildNodes.reserveCapacity(entries.count)

        for index in entries.indices {
            let entry = entries[unchecked: index]
            guard entry.type == .element else { continue }

            switch entry.op {
            case .added, .unchanged, .moved:
                activeChildNodes.append(entry.reference)
                outOfBandLeavingNodes.removeAll { $0 == entry.reference }
            case .removed:
                context.scheduler.flip.markAsRemoved(entry.reference)
                outOfBandLeavingNodes.removeAll { $0 == entry.reference }
            }
        }
    }

    func unmount(_ context: inout _CommitContext) {
        var seen: Set<DOM.Node> = []
        for node in activeChildNodes where seen.insert(node).inserted {
            context.scheduler.flip.markAsRemoved(node)
        }
        for node in outOfBandLeavingNodes where seen.insert(node).inserted {
            context.scheduler.flip.markAsRemoved(node)
        }
        activeChildNodes = []
        outOfBandLeavingNodes = []
    }
}

private extension Transaction {
    var shouldSkipFLIP: Bool {
        // HACK: this is a bit brittle, but a transition removal is currently scheduled as an animation callback
        // and this is a way to identify them... not sure if this will bite us one day
        disablesAnimation && animation == nil
    }
}
