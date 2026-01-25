final class FLIPScheduler {
    private var dom: any DOM.Interactor

    // NOTE: extend this to support css properties as well - for now it is always the bounding rect stuff
    private var scheduledAnimations: [DOM.Node: ScheduledNode] = [:]
    private var runningAnimations: [DOM.Node: GeometryAnimation] = [:]
    private var absolutePositionOriginals: [DOM.Node: PreviousStyleValues] = [:]
    private var firstWindowScrollOffset: (x: Double, y: Double)? = nil

    /// Whether there is pending FLIP work that needs to be committed in RAF
    var hasPendingWork: Bool {
        !scheduledAnimations.isEmpty || !runningAnimations.isEmpty
    }

    init(dom: any DOM.Interactor) {
        self.dom = dom
    }

    func scheduleAnimationOf(_ nodes: [DOM.Node], inParent parentNode: DOM.Node, context: inout _TransactionContext) {
        if firstWindowScrollOffset == nil {
            storeWindowScrollOffset()
        }

        let parentRect = dom.getBoundingClientRect(parentNode)
        for node in nodes {
            guard !scheduledAnimations.keys.contains(node) else {
                logTrace("node \(node) already scheduled for animation")
                continue
            }
            // TODO: we should probably merge stuff or do something better than just ignoring repeated calls
            scheduledAnimations[node] = ScheduledNode(
                transaction: context.transaction,
                geometry: getNodeGeometry(node, scopedTo: parentRect),
                containerNode: parentNode
            )
        }
    }

    func scheduleAnimationOf(_ node: DOM.Node, context: inout _TransactionContext) {
        if firstWindowScrollOffset == nil {
            storeWindowScrollOffset()
        }

        scheduledAnimations[node] = ScheduledNode(
            transaction: context.transaction,
            geometry: getNodeGeometry(node),
            containerNode: nil
        )
    }

    func markAsRemoved(_ node: DOM.Node) {
        scheduledAnimations.removeValue(forKey: node)
        absolutePositionOriginals.removeValue(forKey: node)
        let running = runningAnimations.removeValue(forKey: node)
        running?.cancelAll()
    }

    func markAsLeaving(_ node: DOM.Node) {
        assert(scheduledAnimations[node] != nil, "node not scheduled for animation")

        if dom.needsAbsolutePositioning(node) {
            let rect = dom.getAbsolutePositionCoordinates(node)
            scheduledAnimations[node]?.layoutAction = .moveAbsolute(rect: rect)
        }
    }

    func markAsReentering(_ node: DOM.Node) {
        assert(scheduledAnimations[node] != nil, "node not scheduled for animation")

        if let style = absolutePositionOriginals.removeValue(forKey: node) {
            scheduledAnimations[node]?.layoutAction = .undoMoveAbsolute(style: style)
        }
    }

    func commitScheduledAnimations(context: inout _CommitContext) {
        let scroll = dom.getScrollOffset()
        let firstWindowScroll = firstWindowScrollOffset ?? (x: Double(scroll.x), y: Double(scroll.y))
        self.firstWindowScrollOffset = nil

        commitPreMeasurementChanges(context: &context)

        let lastScroll = dom.getScrollOffset()
        let lastWindowScroll = (x: Double(lastScroll.x), y: Double(lastScroll.y))
        let windowScrollDelta = (x: lastWindowScroll.x - firstWindowScroll.x, y: lastWindowScroll.y - firstWindowScroll.y)

        measureLastAndCreateAnimations(windowScrollDelta: windowScrollDelta, context: &context)

        progressAllAnimations(context: &context)
    }

    private func storeWindowScrollOffset() {
        let scroll = dom.getScrollOffset()
        self.firstWindowScrollOffset = (x: Double(scroll.x), y: Double(scroll.y))
    }

    private func commitPreMeasurementChanges(context: inout _CommitContext) {

        for (node, animation) in scheduledAnimations {
            // TODO: find a good way to preserve velocities of redirected animations
            // undo all running animations that are effected
            runningAnimations[node]?.cancelAll()

            switch animation.layoutAction {
            case .none:
                continue
            case .moveAbsolute(let rect):
                let previousValues = context.dom.fixAbsolutePosition(node, toRect: rect)
                absolutePositionOriginals[node] = previousValues
            case .undoMoveAbsolute(let style):
                context.dom.undoFixAbsolutePosition(node, style: style)
            }
        }
    }

    private func measureLastAndCreateAnimations(windowScrollDelta: (x: Double, y: Double), context: inout _CommitContext) {
        // measures all last states and calculates all new animations

        // parent rect cache
        let parentRects: [DOM.Node: DOM.Rect] = Dictionary(
            uniqueKeysWithValues: Set(scheduledAnimations.values.compactMap { $0.containerNode })
                .compactMap { node -> (DOM.Node, DOM.Rect)? in
                    (node, dom.getBoundingClientRect(node))
                }
        )

        // measure all LAST states
        for (node, animation) in scheduledAnimations {
            // we keep these for cancelling running animations, but there is nothing new to schedule
            guard animation.transaction.animation != nil else { continue }

            var lastGeometry: NodeGeometry

            if let parent = animation.containerNode, let parentRect = parentRects[parent] {
                lastGeometry = getNodeGeometry(node, scopedTo: parentRect)
            } else {
                lastGeometry = getNodeGeometry(node)
            }

            runningAnimations[node] =
                GeometryAnimation(
                    node: node,
                    first: animation.geometry,
                    last: lastGeometry,
                    windowScrollDelta: windowScrollDelta,
                    transaction: animation.transaction,
                    frameTime: context.currentFrameTime
                )
        }

        scheduledAnimations.removeAll()
    }

    private func progressAllAnimations(context: inout _CommitContext) {
        // applies all changes of dirty animations and removes completed ones
        // TODO: optimize
        var removedNodes: [DOM.Node] = []
        for (node, animation) in runningAnimations {
            animation.applyChanges(context: &context)
            if animation.isCompleted {
                removedNodes.append(node)
            }
        }

        for node in removedNodes {
            runningAnimations.removeValue(forKey: node)
        }

        logTrace("running animations: \(runningAnimations.count)")
    }
}

private extension FLIPScheduler {

    enum NodeLayoutAction {
        case none
        case moveAbsolute(rect: DOM.Rect)
        case undoMoveAbsolute(style: PreviousStyleValues)
    }

    struct PreviousStyleValues {
        var position: String
        var left: String
        var top: String
        var width: String
        var height: String
    }

    struct ScheduledNode {
        var transaction: Transaction
        var geometry: NodeGeometry
        var containerNode: DOM.Node?
        var layoutAction: NodeLayoutAction = .none
    }

    struct NodeGeometry {
        var boundingClientRect: DOM.Rect
        var parentRect: DOM.Rect?

        var width: Double
        var height: Double

        func difference(
            from other: NodeGeometry,
            scrollDelta: (x: Double, y: Double)
        ) -> (x: Double, y: Double, width: Double, height: Double) {
            if let parentRect = parentRect, let otherParentRect = other.parentRect {
                return (
                    x: self.boundingClientRect.x - other.boundingClientRect.x - parentRect.x + otherParentRect.x,
                    y: self.boundingClientRect.y - other.boundingClientRect.y - parentRect.y + otherParentRect.y,
                    width: width - other.width,
                    height: height - other.height
                )
            } else {
                return (
                    x: self.boundingClientRect.x - other.boundingClientRect.x - scrollDelta.x,
                    y: self.boundingClientRect.y - other.boundingClientRect.y - scrollDelta.y,
                    width: width - other.width,
                    height: height - other.height
                )
            }
        }
        // NOTE: extend with transform/rotate or other stuff
    }

    final class GeometryAnimation {
        var translation: FLIPAnimation<CSSTransform.Translation>?
        var width: FLIPAnimation<CSSWidth>?
        var height: FLIPAnimation<CSSHeight>?

        var isCompleted: Bool {
            translation == nil && width == nil && height == nil
        }

        init(
            node: DOM.Node,
            first: NodeGeometry,
            last: NodeGeometry,
            windowScrollDelta: (x: Double, y: Double),
            transaction: Transaction,
            frameTime: Double
        ) {
            let (dx, dy, dw, dh) = first.difference(from: last, scrollDelta: windowScrollDelta)

            // TODO: implement scale animation as option

            if shouldAnimateTranslation(dx, dy) {
                self.translation = FLIPAnimation<CSSTransform.Translation>(
                    node: node,
                    first: CSSTransform.Translation(x: Float(dx), y: Float(dy)),
                    last: CSSTransform.Translation(x: 0, y: 0),
                    transaction: transaction,
                    frameTime: frameTime
                )
            }

            if shouldAnimateSizeDelta(dw) {
                self.width = FLIPAnimation<CSSWidth>(
                    node: node,
                    first: CSSWidth(value: first.width),
                    last: CSSWidth(value: last.width),
                    transaction: transaction,
                    frameTime: frameTime
                )
            }

            if shouldAnimateSizeDelta(dh) {
                self.height = FLIPAnimation<CSSHeight>(
                    node: node,
                    first: CSSHeight(value: first.height),
                    last: CSSHeight(value: last.height),
                    transaction: transaction,
                    frameTime: frameTime
                )
            }
        }

        func cancelAll() {
            logTrace("cancelling all animations for node")
            self.translation?.cancel()
            self.width?.cancel()
            self.height?.cancel()

            self.translation = nil
            self.width = nil
            self.height = nil
        }

        func applyChanges(context: inout _CommitContext) {
            translation?.commit(context: &context)
            width?.commit(context: &context)
            height?.commit(context: &context)

            if translation?.isCompleted == true {
                self.translation = nil
            }
            if width?.isCompleted == true {
                self.width = nil
            }
            if height?.isCompleted == true {
                self.height = nil
            }
        }
    }

}

fileprivate extension FLIPScheduler {
    func getNodeGeometry(_ node: DOM.Node, scopedTo parentRect: DOM.Rect? = nil) -> NodeGeometry {
        let rect = dom.getBoundingClientRect(node)

        let width = rect.width
        let height = rect.height

        return NodeGeometry(
            boundingClientRect: rect,
            parentRect: parentRect,
            width: width,
            height: height
        )
    }
}

private func shouldAnimateSizeDelta(_ ds: Double) -> Bool {
    ds > 1 || ds < -1
}

private func shouldAnimateTranslation(_ dx: Double, _ dy: Double) -> Bool {
    dx > 1 || dx < -1 || dy > 1 || dy < -1
}

extension DOM.Interactor {
    func needsAbsolutePositioning(_ node: DOM.Node) -> Bool {
        let computedStyle = makeComputedStyleAccessor(node)
        let position = computedStyle.get("position")
        return !position.utf8Equals("absolute") && !position.utf8Equals("fixed")
    }

    func getAbsolutePositionCoordinates(_ node: DOM.Node) -> DOM.Rect {
        let nodeRect = getBoundingClientRect(node)

        if let positionedAncestor = getOffsetParent(node) {
            logTrace("positioned ancestor: \(positionedAncestor)")
            let ancestorRect = getBoundingClientRect(positionedAncestor)
            logTrace("ancestor rect: \(ancestorRect)")
            return DOM.Rect(x: nodeRect.x - ancestorRect.x, y: nodeRect.y - ancestorRect.y, width: nodeRect.width, height: nodeRect.height)
        }

        return nodeRect
    }
}

private extension DOM.Interactor {
    func fixAbsolutePosition(_ node: DOM.Node, toRect rect: DOM.Rect) -> FLIPScheduler.PreviousStyleValues {
        let stylePosition = makeStyleAccessor(node, cssName: "position")
        let styleLeft = makeStyleAccessor(node, cssName: "left")
        let styleTop = makeStyleAccessor(node, cssName: "top")
        let styleWidth = makeStyleAccessor(node, cssName: "width")
        let styleHeight = makeStyleAccessor(node, cssName: "height")

        // Extract previous style values for later reversal
        let previousValues = FLIPScheduler.PreviousStyleValues(
            position: stylePosition.get(),
            left: styleLeft.get(),
            top: styleTop.get(),
            width: styleWidth.get(),
            height: styleHeight.get()
        )

        logTrace(
            "setting position of node \(node) to absolute, left: \(rect.x)px, top: \(rect.y)px, width: \(rect.width)px, height: \(rect.height)px"
        )

        stylePosition.set("absolute")
        styleLeft.set("\(rect.x)px")
        styleTop.set("\(rect.y)px")
        styleWidth.set("\(rect.width)px")
        styleHeight.set("\(rect.height)px")

        return previousValues
    }

    func undoFixAbsolutePosition(_ node: DOM.Node, style: FLIPScheduler.PreviousStyleValues) {
        let stylePosition = makeStyleAccessor(node, cssName: "position")
        let styleLeft = makeStyleAccessor(node, cssName: "left")
        let styleTop = makeStyleAccessor(node, cssName: "top")
        let styleWidth = makeStyleAccessor(node, cssName: "width")
        let styleHeight = makeStyleAccessor(node, cssName: "height")

        stylePosition.set(style.position)
        styleLeft.set(style.left)
        styleTop.set(style.top)
        styleWidth.set(style.width)
        styleHeight.set(style.height)
    }
}
