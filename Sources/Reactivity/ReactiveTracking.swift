/// Synchronous tracking of reactive dependencies.
///
/// Shaped after the persistent listeners pitched for Swift's Observation, with dependencies
/// collected before a listener exists, and trimmed to what views need: a callback before
/// each change to anything a body read.
package enum ReactiveTracking {
    /// The result of ``track(_:)``: the value, and what was read to compute it.
    package struct TrackingResult<Value>: ~Copyable {
        package var value: Value
        /// `nil` if nothing reactive was read.
        package var dependencies: AccessedDependencies?

        init(value: Value, dependencies: consuming AccessedDependencies?) {
            self.value = value
            self.dependencies = dependencies
        }

        /// Moves the value out of the result, without copying it. Take `dependencies` first.
        package consuming func takeValue() -> Value { value }
    }

    /// Runs `apply` and collects the reactive properties it reads, without observing them.
    ///
    /// Pass the dependencies to ``Listener/init(tracking:onChange:)`` to start observing
    /// them. If nothing was read, no listener needs to be created.
    package static func track<Value>(_ apply: () -> Value) -> TrackingResult<Value> {
        var dependencies = AccessedDependencies()
        let value = dependencies.collect(apply)
        if dependencies.isEmpty {
            return TrackingResult(value: value, dependencies: nil)
        }
        return TrackingResult(value: value, dependencies: dependencies)
    }

    /// Observes a set of reactive properties that can be replaced by tracking again.
    ///
    /// `onChange` runs synchronously on the writer's thread, before each change. Dropping
    /// the listener ends all observation; a handler that is already running may finish.
    package struct Listener: ~Copyable, Sendable {
        private let core: _ListenerCore
        private var dependencies: AccessedDependencies

        /// Starts observing dependencies collected by ``ReactiveTracking/track(_:)``, if any.
        package init(
            tracking dependencies: consuming AccessedDependencies? = nil,
            onChange: @escaping @Sendable () -> Void
        ) {
            core = _ListenerCore(onChange: onChange)
            self.dependencies = dependencies ?? AccessedDependencies()
            self.dependencies.observe(by: core)
        }

        /// Runs `apply` and replaces the observed properties with the ones it reads.
        /// The reads are also reported to enclosing tracking scopes.
        package mutating func track<T>(_ apply: () -> T) -> T {
            dependencies.collect(observedBy: core, apply)
        }

        deinit {
            // Cancel first: a notification in progress may still hold a snapshot with `core`.
            core.cancel()
            dependencies.unsubscribe(core)
        }
    }
}
