extension ReactiveTracking {
    /// The reactive properties read while tracking.
    ///
    /// A listener re-tracks into the same table. Each tracking pass stamps the accesses
    /// it reads with a new generation: afterwards, accesses with an older stamp were not
    /// read again, and accesses that are not subscribed yet are new. Re-tracking stable
    /// dependencies therefore neither allocates nor touches any tracker.
    package struct AccessedDependencies: ~Copyable, @unchecked Sendable {
        // Unchecked: `enclosing` is only set during a tracking pass, which has exclusive access.
        private struct Stamp {
            var generation: UInt32
            var isSubscribed = false
        }

        private var accesses: [_Access: Stamp] = [:]
        private var generation: UInt32 = 0
        /// Accesses of the current pass that were already known.
        private var revisited = 0
        /// Accesses of the current pass that are new.
        private var added = 0
        /// While tracking: the enclosing tracking pass, which also records every read.
        private var enclosing: UnsafeMutablePointer<Self>?

        init() {}

        package var isEmpty: Bool { accesses.isEmpty }

        /// Runs `apply` as a new tracking pass that records the reactive properties it reads.
        /// With a `listener`, the listener then observes exactly what the pass read.
        ///
        /// The current thread's tracking passes form a chain through `enclosing`,
        /// starting at the innermost one.
        mutating func collect<T>(observedBy listener: _ListenerCore? = nil, _ apply: () -> T) -> T {
            generation &+= 1
            revisited = 0
            added = 0
            enclosing = Self.current
            let value = withUnsafeMutablePointer(to: &self) { pass in
                _ThreadLocal.value = UnsafeMutableRawPointer(pass)
                defer {
                    _ThreadLocal.value = pass.pointee.enclosing.map { UnsafeMutableRawPointer($0) }
                    pass.pointee.enclosing = nil
                }
                return apply()
            }
            if let listener { observe(by: listener) }
            return value
        }

        /// The innermost tracking pass of the current thread, if any.
        private static var current: UnsafeMutablePointer<Self>? {
            _ThreadLocal.value?.assumingMemoryBound(to: Self.self)
        }

        static var isTracking: Bool { _ThreadLocal.value != nil }

        /// Records a read in the current tracking pass and all passes enclosing it.
        static func record(_ access: _Access) {
            var pass = current
            while let current = pass {
                current.pointee.record(access)
                pass = current.pointee.enclosing
            }
        }

        private mutating func record(_ access: _Access) {
            if let index = accesses.index(forKey: access) {
                guard accesses.values[index].generation != generation else { return }
                accesses.values[index].generation = generation
                revisited += 1
            } else {
                accesses[access] = Stamp(generation: generation)
                added += 1
            }
        }

        /// Makes `listener` observe exactly the accesses of the last pass: subscribes it to the
        /// new ones, and drops the ones the pass did not read. Calling it again changes nothing.
        mutating func observe(by listener: _ListenerCore) {
            if accesses.count > revisited + added {
                for (access, stamp) in accesses where stamp.generation != generation {
                    access.tracker.unsubscribe(listener, from: access.property)
                }
                accesses = accesses.filter { $0.value.generation == generation }
            }
            guard added > 0 else { return }
            var index = accesses.startIndex
            while index != accesses.endIndex {
                if !accesses.values[index].isSubscribed {
                    let access = accesses.keys[index]
                    access.tracker.subscribe(listener, to: access.property)
                    accesses.values[index].isSubscribed = true
                }
                accesses.formIndex(after: &index)
            }
        }

        /// Calls `onChange` on the first change to any of the dependencies.
        // Not generic: in Embedded Swift, a class initialized from generic code is initialized in
        // the client module, which the optimizer doesn't consider when it folds `let` properties.
        consuming func observeOnce(_ onChange: @escaping @Sendable () -> Void) {
            observe(by: _ListenerCore(.oneShot, onChange: onChange))
        }

        func unsubscribe(_ listener: _ListenerCore) {
            for (access, stamp) in accesses where stamp.isSubscribed {
                access.tracker.unsubscribe(listener, from: access.property)
            }
        }
    }
}

/// A read of one property of one registrar.
struct _Access: Hashable, Sendable {
    let tracker: ReactivityTracker
    let property: PropertyID

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tracker === rhs.tracker && lhs.property == rhs.property
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(tracker))
        hasher.combine(property)
    }
}
