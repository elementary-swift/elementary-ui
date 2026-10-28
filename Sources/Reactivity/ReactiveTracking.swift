/// Synchronous tracking of reactive dependencies.
package enum ReactiveTracking {
    /// Runs `apply` and collects the reactive properties it reads into `dependencies`, without
    /// observing them; `nil` if nothing reactive was read.
    @inlinable
    package static func track<Value>(
        into dependencies: inout AccessedDependencies?,
        _ apply: () -> Value
    ) -> Value {
        var accessed = AccessedDependencies()
        let value = accessed.collect(apply)
        if accessed.isEmpty {
            dependencies = nil
        } else {
            dependencies = consume accessed
        }
        return value
    }

    /// Observes reactive properties, which `track` replaces. `onChange` runs synchronously
    /// on the writer's thread, before each change.
    package struct Listener: ~Copyable, Sendable {
        @usableFromInline
        let core: _ListenerCore
        @usableFromInline
        var dependencies: AccessedDependencies

        /// Starts observing dependencies collected by ``ReactiveTracking/track(into:_:)``.
        package init(tracking dependencies: consuming AccessedDependencies, onChange: @escaping @Sendable () -> Void) {
            self.init(tracking: dependencies, handler: .closure(onChange))
        }

        /// Starts observing dependencies collected by ``ReactiveTracking/track(into:_:)``, calling
        /// `onChange` with `context`. `context` must stay valid until the listener is cancelled or dropped.
        package init(
            tracking dependencies: consuming AccessedDependencies,
            context: UnsafeMutableRawPointer,
            onChange: @convention(c) (UnsafeMutableRawPointer) -> Void
        ) {
            self.init(tracking: dependencies, handler: .function(context: context, onChange: onChange))
        }

        private init(tracking dependencies: consuming AccessedDependencies, handler: _ListenerHandler) {
            core = _ListenerCore(handler: handler)
            self.dependencies = dependencies
            self.dependencies.observe(by: core)
        }

        /// Runs `apply` and replaces the observed properties with the ones it reads.
        /// The reads are also reported to enclosing tracking scopes.
        @inlinable
        package mutating func track<T>(_ apply: () -> T) -> T {
            dependencies.collect(observedBy: core, apply)
        }

        /// Stops the listener; it is not notified again. Dropping it does the same.
        package consuming func cancel() {
            // Consuming `self` runs `deinit`, which cancels and unsubscribes.
        }

        deinit {
            // Cancel first: a notification in progress may still hold a snapshot with `core`.
            core.cancel()
            dependencies.release(core)
        }
    }
}
