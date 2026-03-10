struct _TransactionModifierView<Wrapped: View, Value: Equatable>: View {
    public typealias Tag = Wrapped.Tag
    public typealias Content = Never
    public typealias _MountedNode = _StatefulNode<State, Wrapped._MountedNode>

    struct State {
        var value: Value
    }

    var view: Wrapped
    var value: Value
    var transactionModifier: (inout Transaction) -> Void

    public static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        let node = Wrapped._makeNode(view.view, context: context, tx: &tx)
        return .init(state: .init(value: view.value), child: node)
    }

    public static func _patchNode(
        _ view: consuming Self,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {
        if node.state.value != view.value {
            node.state.value = view.value
            tx.withModifiedTransaction(view.transactionModifier) { tx in
                Wrapped._patchNode(view.view, node: &node.child, tx: &tx)
            }
        } else {
            Wrapped._patchNode(view.view, node: &node.child, tx: &tx)
        }
    }
}

extension View {
    /// Applies a transaction transform when a value changes.
    ///
    /// Use this modifier to customize the transaction used for updates when
    /// a specific value changes. This allows fine-grained control over animations
    /// and other transaction properties.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @View
    /// struct Content {
    ///     @State var count: Int = 0
    ///     @State var disableAnimation: Bool = false
    ///
    ///     var body: some View {
    ///         div { "Count: \(count)" }
    ///             .transaction(value: count) { transaction in
    ///                 transaction.animation = .smooth
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - value: A value to monitor for changes. When this value changes,
    ///     the transform is applied to the transaction.
    ///   - transform: A closure that modifies the transaction.
    /// - Returns: A view that uses the transformed transaction when the value changes.
    public func transaction<Value: Equatable>(
        value: Value,
        _ transform: @escaping (inout Transaction) -> Void
    ) -> some View<Self.Tag> {
        _TransactionModifierView(view: self, value: value, transactionModifier: transform)
    }

    /// Applies an animation when a value changes.
    ///
    /// Use this modifier to automatically animate changes to a view when a specific
    /// value changes, without wrapping the state changes in ``withAnimation(_:_:)``.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @View
    /// struct AnimatedBox {
    ///     @State var isExpanded: Bool = false
    ///
    ///     var body: some View {
    ///         div {
    ///             button { "Toggle" }
    ///                 .onClick { isExpanded.toggle() }
    ///
    ///             if isExpanded {
    ///                 div { "Expanded content" }
    ///             }
    ///         }
    ///         .animation(.smooth, value: isExpanded)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - animation: The animation to use, or `nil` to disable animation.
    ///   - value: A value to monitor for changes. When this value changes,
    ///     the animation is applied.
    /// - Returns: A view that animates changes when the value changes.
    public func animation<Value: Equatable>(
        _ animation: Animation?,
        value: Value,
    ) -> some View<Self.Tag> {
        _TransactionModifierView(view: self, value: value) { $0.animation = animation }
    }
}
