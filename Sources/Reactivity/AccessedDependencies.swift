extension ReactiveTracking {
    /// The reactive properties read while tracking.
    ///
    /// Each tracking pass stamps the accesses it reads with a new generation: accesses with an
    /// older stamp were not read again, unsubscribed ones are new. A listener re-tracks into
    /// the same table, so stable dependencies cost no allocations.
    package struct AccessedDependencies: ~Copyable, @unchecked Sendable {
        // Unchecked: `enclosingPass` is only set during a tracking pass, which has exclusive access.
        private var accesses = _AccessTable()
        /// Wrapping is safe: observing a pass removes the accesses it did not read, so stamps
        /// only ever need to tell the current generation from the previous one.
        private var generation: UInt8 = 0
        private var knownAccessCount = 0
        private var newAccessCount = 0
        /// While tracking: the enclosing pass, which records every read as well.
        private var enclosingPass: UnsafeMutablePointer<Self>?

        @usableFromInline
        init() {}

        package var isEmpty: Bool { accesses.isEmpty }

        /// Runs `apply` as a new tracking pass. With a `listener`, the listener then observes
        /// exactly what the pass read.
        ///
        /// Only the call to `apply` is generic and inlined; the rest of the pass is not.
        @inlinable
        mutating func collect<T>(observedBy listener: _ListenerCore? = nil, _ apply: () -> T) -> T {
            let value = withUnsafeMutablePointer(to: &self) { pass in
                Self.beginPass(pass)
                defer { Self.endPass(pass) }
                return apply()
            }
            if let listener { observe(by: listener) }
            return value
        }

        @usableFromInline
        static func beginPass(_ pass: UnsafeMutablePointer<Self>) {
            pass.pointee.generation &+= 1
            pass.pointee.knownAccessCount = 0
            pass.pointee.newAccessCount = 0
            pass.pointee.enclosingPass = current
            _ThreadLocal.value = UnsafeMutableRawPointer(pass)
        }

        @usableFromInline
        static func endPass(_ pass: UnsafeMutablePointer<Self>) {
            _ThreadLocal.value = pass.pointee.enclosingPass.map { UnsafeMutableRawPointer($0) }
            pass.pointee.enclosingPass = nil
        }

        private static var current: UnsafeMutablePointer<Self>? {
            _ThreadLocal.value?.assumingMemoryBound(to: Self.self)
        }

        /// Records a read in the current pass and all enclosing ones.
        static func record(_ access: _Access) {
            var nextPass = current
            while let pass = nextPass {
                pass.pointee.record(access)
                nextPass = pass.pointee.enclosingPass
            }
        }

        private mutating func record(_ access: _Access) {
            switch accesses.record(access, generation: generation) {
            case .repeated: break
            case .known: knownAccessCount += 1
            case .new: newAccessCount += 1
            }
        }

        /// Makes `listener` observe exactly the accesses of the last pass. Idempotent.
        @usableFromInline
        mutating func observe(by listener: _ListenerCore) {
            let hasUnreadAccesses = accesses.count > knownAccessCount + newAccessCount
            if hasUnreadAccesses {
                accesses.removeAll(notReadIn: generation) { access in
                    access.tracker.unsubscribe(listener, from: access.property)
                }
            }
            guard newAccessCount > 0 else { return }
            accesses.subscribeNew { access in
                access.tracker.subscribe(listener, to: access.property)
            }
        }

        /// Calls `onChange` on the first change to any of the dependencies.
        // Not generic, to avoid a Swift 6.4 Embedded miscompile: `let` properties of a class
        // initialized from generic code in another module can be folded to a wrong constant.
        consuming func observeOnce(_ onChange: @escaping @Sendable () -> Void) {
            observe(by: _ListenerCore(.oneShot, handler: .closure(onChange)))
        }

        /// Releases a cancelled listener from every property it observes.
        func release(_ listener: _ListenerCore) {
            accesses.forEachSubscribed { access in
                access.tracker.release(listener, from: access.property)
            }
        }
    }
}

/// A read of one property of one registrar. Usable from inline: inlined `track` calls destroy it.
@usableFromInline
struct _Access: Hashable, Sendable {
    let tracker: ReactivityTracker
    let property: PropertyID

    @usableFromInline
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tracker === rhs.tracker && lhs.property == rhs.property
    }

    @usableFromInline
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(tracker))
        hasher.combine(property)
    }
}

/// The accesses of a tracking pass, with their stamps. Passes mostly read a handful of
/// properties, which are kept inline so that tracking allocates nothing; more are kept in a
/// dictionary. A struct rather than an enum, so that a read updates it in place.
@usableFromInline
struct _AccessTable: ~Copyable {
    private var entries = InlineArray<3, Entry?>(repeating: nil)
    private var entryCount = 0
    /// Replaces `entries` once a pass reads more than they hold.
    private var dictionary: [_Access: Stamp]?

    @usableFromInline
    struct Stamp {
        var generation: UInt8
        var isSubscribed = false

        /// Stamps a read; returns whether it was already read in this generation.
        mutating func stamp(_ generation: UInt8) -> _AccessTable.Recorded {
            guard self.generation != generation else { return .repeated }
            self.generation = generation
            return .known
        }
    }

    @usableFromInline
    struct Entry {
        let access: _Access
        var stamp: Stamp
    }

    enum Recorded {
        /// Already read in this pass.
        case repeated
        /// Read in an earlier pass.
        case known
        case new
    }

    private static var inlineCapacity: Int { 3 }

    init() {}

    var count: Int { dictionary?.count ?? entryCount }

    var isEmpty: Bool { count == 0 }

    mutating func record(_ access: _Access, generation: UInt8) -> Recorded {
        if dictionary != nil { return recordInDictionary(access, generation: generation) }

        var span = entries.mutableSpan
        for index in 0..<entryCount where span[index]!.access == access {
            return span[index]!.stamp.stamp(generation)
        }
        guard entryCount == Self.inlineCapacity else {
            span[entryCount] = Entry(access: access, stamp: Stamp(generation: generation))
            entryCount += 1
            return .new
        }
        var accesses = [_Access: Stamp](minimumCapacity: 2 * Self.inlineCapacity)
        for index in span.indices {
            let entry = span[index].take()!
            accesses[entry.access] = entry.stamp
        }
        entryCount = 0
        accesses[access] = Stamp(generation: generation)
        dictionary = accesses
        return .new
    }

    private mutating func recordInDictionary(_ access: _Access, generation: UInt8) -> Recorded {
        if let index = dictionary!.index(forKey: access) {
            return dictionary!.values[index].stamp(generation)
        }
        dictionary![access] = Stamp(generation: generation)
        return .new
    }

    /// Removes the accesses not read in `generation`, passing the subscribed ones to `removed`.
    mutating func removeAll(notReadIn generation: UInt8, _ removed: (_Access) -> Void) {
        if let accesses = dictionary {
            for (access, stamp) in accesses where stamp.generation != generation && stamp.isSubscribed {
                removed(access)
            }
            dictionary = accesses.filter { $0.value.generation == generation }
            return
        }

        var span = entries.mutableSpan
        var keptCount = 0
        for index in 0..<entryCount {
            let entry = span[index].take()!
            if entry.stamp.generation == generation {
                span[keptCount] = entry
                keptCount += 1
            } else if entry.stamp.isSubscribed {
                removed(entry.access)
            }
        }
        entryCount = keptCount
    }

    /// Passes each access not yet subscribed to `subscribe`, and marks it subscribed.
    mutating func subscribeNew(_ subscribe: (_Access) -> Void) {
        if dictionary != nil {
            var index = dictionary!.startIndex
            while index != dictionary!.endIndex {
                if !dictionary!.values[index].isSubscribed {
                    subscribe(dictionary!.keys[index])
                    dictionary!.values[index].isSubscribed = true
                }
                dictionary!.formIndex(after: &index)
            }
            return
        }

        var span = entries.mutableSpan
        for index in 0..<entryCount where !span[index]!.stamp.isSubscribed {
            subscribe(span[index]!.access)
            span[index]!.stamp.isSubscribed = true
        }
    }

    func forEachSubscribed(_ body: (_Access) -> Void) {
        if let accesses = dictionary {
            for (access, stamp) in accesses where stamp.isSubscribed {
                body(access)
            }
            return
        }

        let span = entries.span
        for index in 0..<entryCount where span[index]!.stamp.isSubscribed {
            body(span[index]!.access)
        }
    }
}
