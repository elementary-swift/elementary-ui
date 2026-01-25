public extension View {
    /// Adds an action to perform when the given value changes.
    ///
    /// - Parameters:
    ///   - value: The value to observe for changes.
    ///   - initial: Whether the action should be run when the view initially appears.
    ///   - action: The action to perform when a change is detected.
    /// - Returns: A view that triggers the given action when the value changes.
    func onChange<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View<Tag> {
        _OnChangeView(wrapped: self, value: value, initial: initial) { _, _ in action() }
    }

    /// Adds an action to perform when the given value changes, providing both the old and new values.
    ///
    /// - Parameters:
    ///   - value: The value to observe for changes.
    ///   - initial: Whether the action should be run when the view initially appears.
    ///   - action: The action to perform when a change is detected, receiving the old and new values.
    /// - Returns: A view that triggers the given action when the value changes.
    nonisolated func onChange<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping (V, V) -> Void
    ) -> some View<Tag> {
        _OnChangeView(wrapped: self, value: value, initial: initial, action: action)
    }
}

struct _OnChangeView<Wrapped: View, Value: Equatable>: View {
    typealias Tag = Wrapped.Tag
    typealias _MountedNode = _StatefulNode<State, Wrapped._MountedNode>

    struct State {
        var value: Value
        var action: (Value, Value) -> Void

        init(value: Value, action: @escaping (Value, Value) -> Void) {
            self.value = value
            self.action = action
        }
    }

    let wrapped: Wrapped
    let value: Value
    let initial: Bool
    let action: (Value, Value) -> Void

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        let state = State(value: view.value, action: view.action)
        let child = Wrapped._makeNode(view.wrapped, context: context, tx: &tx)

        if view.initial {
            let initialValue = view.value
            let action = view.action
            tx.scheduler.afterCommit {
                action(initialValue, initialValue)
            }
        }

        return .init(state: state, child: child)
    }

    static func _patchNode(
        _ view: consuming Self,
        node: _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.action = view.action

        if node.state.value != view.value {
            let oldValue = node.state.value
            let newValue = view.value
            node.state.value = newValue

            let action = view.action
            tx.scheduler.afterCommit {
                action(oldValue, newValue)
            }
        }

        Wrapped._patchNode(view.wrapped, node: node.child, tx: &tx)
    }
}
