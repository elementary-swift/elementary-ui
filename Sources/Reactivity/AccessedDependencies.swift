extension ReactiveTracking {
    /// The reactive properties read while tracking.
    ///
    /// Each tracking pass stamps the accesses it reads with a new generation: accesses with an
    /// older stamp were not read again, unsubscribed ones are new. A listener re-tracks into
    /// the same table, so stable dependencies cost no allocations.
    package struct AccessedDependencies: ~Copyable, @unchecked Sendable {
        // Unchecked: `enclosingPass` is only set during a tracking pass, which has exclusive access.
        private struct Stamp {
            var generation: UInt32
            var isSubscribed = false
        }

        private var accesses: [_Access: Stamp] = [:]
        /// Wrapping is safe: stamps are only compared for equality with the current generation.
        private var generation: UInt32 = 0
        private var knownAccessCount = 0
        private var newAccessCount = 0
        /// While tracking: the enclosing pass, which records every read as well.
        private var enclosingPass: UnsafeMutablePointer<Self>?

        init() {}

        package var isEmpty: Bool { accesses.isEmpty }

        /// Runs `apply` as a new tracking pass. With a `listener`, the listener then observes
        /// exactly what the pass read.
        mutating func collect<T>(observedBy listener: _ListenerCore? = nil, _ apply: () -> T) -> T {
            generation &+= 1
            knownAccessCount = 0
            newAccessCount = 0
            enclosingPass = Self.current
            let value = withUnsafeMutablePointer(to: &self) { pass in
                _ThreadLocal.value = UnsafeMutableRawPointer(pass)
                defer {
                    _ThreadLocal.value = pass.pointee.enclosingPass.map { UnsafeMutableRawPointer($0) }
                    pass.pointee.enclosingPass = nil
                }
                return apply()
            }
            if let listener { observe(by: listener) }
            return value
        }

        private static var current: UnsafeMutablePointer<Self>? {
            _ThreadLocal.value?.assumingMemoryBound(to: Self.self)
        }

        static var isTracking: Bool { _ThreadLocal.value != nil }

        /// Records a read in the current pass and all enclosing ones.
        static func record(_ access: _Access) {
            var nextPass = current
            while let pass = nextPass {
                pass.pointee.record(access)
                nextPass = pass.pointee.enclosingPass
            }
        }

        private mutating func record(_ access: _Access) {
            if let index = accesses.index(forKey: access) {
                guard accesses.values[index].generation != generation else { return }
                accesses.values[index].generation = generation
                knownAccessCount += 1
            } else {
                accesses[access] = Stamp(generation: generation)
                newAccessCount += 1
            }
        }

        /// Makes `listener` observe exactly the accesses of the last pass. Idempotent.
        mutating func observe(by listener: _ListenerCore) {
            let hasUnreadAccesses = accesses.count > knownAccessCount + newAccessCount
            if hasUnreadAccesses {
                for (access, stamp) in accesses where stamp.generation != generation {
                    access.tracker.unsubscribe(listener, from: access.property)
                }
                accesses = accesses.filter { $0.value.generation == generation }
            }
            guard newAccessCount > 0 else { return }
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
        // Not generic, to avoid a Swift 6.4 Embedded miscompile: `let` properties of a class
        // initialized from generic code in another module can be folded to a wrong constant.
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
