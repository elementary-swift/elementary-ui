struct AnimateContainerLayoutView<Wrapped: View>: View {
    typealias Tag = Wrapped.Tag
    typealias _MountedNode = _StatefulNode<FLIPLayoutObserver, Wrapped._MountedNode>

    var animateContainerSize: Bool = true
    var wrapped: Wrapped

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _CommitContext
    ) -> _MountedNode {

        let observer = FLIPLayoutObserver(
            animateContainerSize: view.animateContainerSize
        )

        var context = copy context
        context.layoutObservers.add(observer)

        return _MountedNode(
            state: observer,
            child: Wrapped._makeNode(view.wrapped, context: context, ctx: &ctx)
        )
    }

    static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.update(animateContainerSize: view.animateContainerSize)
        Wrapped._patchNode(view.wrapped, node: &node.child, tx: &tx)
    }
}

public extension View {
    /// Automatically animates layout changes when children are modified within an element.
    ///
    /// This modifier observes when children inside the element it's attached to are added, removed,
    /// or reordered, and automatically animates their layout transitions. It uses the FLIP
    /// (First, Last, Invert, Play) technique to create smooth animations.
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     @State var items = ["Item 1", "Item 2", "Item 3"]
    ///
    ///     var body: some View {
    ///         div {
    ///             ForEach(items, key: { $0 }) { item in
    ///                 p { item }
    ///             }
    ///         }
    ///         .animateContainerLayout()
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter animateContainerSize: Whether to animate changes to the container's size.
    ///   Defaults to `true`.
    /// - Returns: A view that animates layout changes when its children are modified with an animation.
    func animateContainerLayout(
        animateContainerSize: Bool = true
    ) -> some View<Self.Tag> {
        AnimateContainerLayoutView(
            animateContainerSize: animateContainerSize,
            wrapped: self
        )
    }
}
