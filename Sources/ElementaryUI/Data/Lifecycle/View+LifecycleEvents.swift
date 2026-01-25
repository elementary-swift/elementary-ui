import _Concurrency

public extension View {
    /// Adds an action to perform when this view appears.
    ///
    /// Use this modifier to run code when a view is added to the view hierarchy.
    /// This is useful for initializing state, starting timers, or setting up
    /// external resources.
    ///
    /// > Note: This fires when the view appears in the view hierarchy, not when
    /// > it becomes visible on screen. Views can be present in the hierarchy but
    /// > hidden or scrolled out of view.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Hello, world!" }
    ///     .onAppear {
    ///         print("View mounted")
    ///     }
    /// ```
    ///
    /// - Parameter action: A closure to execute after the view appears.
    /// - Returns: A view that performs the action on mount.
    func onAppear(_ action: @escaping () -> Void) -> some View<Tag> {
        _LifecycleEventView(wrapped: self, listener: .onAppear(action))
    }

    /// Adds an action to perform when this view disappears.
    ///
    /// Use this modifier to run cleanup code when a view is removed from the view hierarchy.
    /// This is useful for releasing resources, canceling timers, or removing listeners.
    ///
    /// > Note: This fires when the view is removed from the view hierarchy, not when
    /// > it is hidden or scrolled out of view. Views can be present in the hierarchy but
    /// > hidden or scrolled out of view.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// div { "Temporary content" }
    ///     .onUnmount {
    ///         print("View removed")
    ///         cleanupResources()
    ///     }
    /// ```
    ///
    /// - Parameter action: A closure to execute before the view disappears.
    /// - Returns: A view that performs the action on unmount.
    func onDisappear(_ action: @escaping () -> Void) -> some View<Tag> {
        _LifecycleEventView(wrapped: self, listener: .onDisappear(action))
    }

    /// Adds an asynchronous task to run when this view appears.
    ///
    /// Use this modifier to run async operations when a view is added to the view hierarchy. The task
    /// is automatically cancelled when the view is removed.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @View
    /// struct UserProfile {
    ///     @State var user: User?
    ///
    ///     var body: some View {
    ///         div {
    ///             if let user {
    ///                 p { user.name }
    ///             } else {
    ///                 p { "Loading..." }
    ///             }
    ///         }
    ///         .task {
    ///             user = await fetchUser()
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter task: An async closure to execute when the view appears.
    ///   The task is cancelled when the view disappears.
    /// - Returns: A view that performs the task on mount and cancels it on unmount.
    func task(_ task: @escaping () async -> Void) -> some View<Tag> {
        _LifecycleEventView(
            wrapped: self,
            listener: .onAppearReturningCancelFunction({ Task { await task() }.cancel })
        )
    }
}

enum LifecycleHook {
    case onAppear(() -> Void)
    case onDisappear(() -> Void)
    case onAppearReturningCancelFunction(() -> () -> Void)
}

struct _LifecycleEventView<Wrapped: View>: View {
    typealias Tag = Wrapped.Tag
    typealias _MountedNode = _StatefulNode<LifecycleState, Wrapped._MountedNode>

    let wrapped: Wrapped
    let listener: LifecycleHook

    final class LifecycleState: Unmountable {
        var onUnmount: (() -> Void)?

        init(hook: LifecycleHook, tx: borrowing _TransactionContext) {

            switch hook {
            case .onAppear(let onAppear):
                tx.scheduler.afterCommit { onAppear() }
            case .onDisappear(let callback):
                self.onUnmount = callback
            case .onAppearReturningCancelFunction(let onAppearReturningCancelFunction):
                tx.scheduler.afterCommit {
                    let cancelFunc = onAppearReturningCancelFunction()
                    self.onUnmount = cancelFunc
                }
            }
        }

        func unmount(_ context: inout _CommitContext) {
            context.scheduler.afterCommit {
                self.onUnmount?()
                self.onUnmount = nil
            }
        }
    }

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        let state = LifecycleState(hook: view.listener, tx: tx)
        let child = Wrapped._makeNode(view.wrapped, context: context, tx: &tx)

        let node = _StatefulNode(state: state, child: child)
        return node
    }

    static func _patchNode(
        _ view: consuming Self,
        node: _MountedNode,
        tx: inout _TransactionContext
    ) {
        switch view.listener {
        case .onDisappear(let callback):
            // unmount is the only lifecycle hook that can be patched
            node.state.onUnmount = callback
        default:
            break
        }

        Wrapped._patchNode(view.wrapped, node: node.child, tx: &tx)
    }
}
