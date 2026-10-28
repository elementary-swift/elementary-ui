import Synchronization

/// The listeners subscribed to the properties of one registrar.
///
/// A write first checks a bitmask of the property indices that may be observed,
/// so writes to unobserved properties don't take the lock.
@usableFromInline
final class ReactivityTracker: Sendable {
    private let table = Mutex(_SubscriptionTable())
    @usableFromInline
    let observedMask = Atomic<UInt64>(0)

    func subscribe(_ listener: _ListenerCore, to property: PropertyID) {
        withTable { $0.update(property, inserting: listener) }
    }

    /// Removes a listener that stopped reading the property.
    func unsubscribe(_ listener: _ListenerCore, from property: PropertyID) {
        withTable { $0.update(property) { $0.remove(listener) } }
    }

    /// Removes a cancelled listener. Cheap when many listeners observe the property: cancelled
    /// listeners are skipped when notifying and removed in batches.
    func release(_ listener: _ListenerCore, from property: PropertyID) {
        withTable { $0.update(property) { $0.release(listener) } }
    }

    @inlinable
    func notify(_ property: PropertyID) {
        guard observedMask.load(ordering: .relaxed) & property.observationBit != 0 else { return }
        notifyListeners(of: property)
    }

    // Keeps the rarely taken path out of every property setter.
    @usableFromInline
    @inline(never)
    func notifyListeners(of property: PropertyID) {
        // Listeners run outside the lock, from a snapshot; a listener dropped meanwhile is skipped.
        guard let listeners = withTable({ $0.listeners(for: property) }) else { return }
        let hasFinishedOneShots = listeners.notify()
        if hasFinishedOneShots {
            withTable { $0.update(property) { $0.removeCancelled() } }
        }
    }

    func withTable<Result>(_ body: (inout _SubscriptionTable) -> Result) -> Result {
        table.withLock { table in
            let mask = table.mask
            let result = body(&table)
            // Publish under the lock so that concurrent updates can't reorder the mask.
            if table.mask != mask { observedMask.store(table.mask, ordering: .relaxed) }
            return result
        }
    }
}

struct _SubscriptionTable: ~Copyable {
    // Not `UniqueDictionary`: stored in the `Mutex`, it crashed with swift-collections 1.7.
    private var subscribers: [PropertyID: _Subscribers] = [:]

    /// A superset of the observed property indices. Removing a property only marks it stale.
    private(set) var mask: UInt64 = 0
    private var isMaskStale = false

    fileprivate mutating func update(_ property: PropertyID, inserting listener: _ListenerCore) {
        if let index = subscribers.index(forKey: property) {
            subscribers.values[index].insert(listener)
        } else {
            subscribers[property] = _Subscribers(listener)
        }
        mask |= property.observationBit
    }

    /// Applies `body` to the property's listeners; it returns `true` when none remain.
    fileprivate mutating func update(_ property: PropertyID, _ body: (inout _Subscribers) -> Bool) {
        guard let index = subscribers.index(forKey: property) else { return }
        if body(&subscribers.values[index]) {
            subscribers.remove(at: index)
            isMaskStale = true
        }
    }

    /// On a miss, also narrows a stale mask.
    mutating func listeners(for property: PropertyID) -> _Subscribers? {
        if let listeners = subscribers[property] { return listeners }
        if isMaskStale {
            mask = subscribers.keys.reduce(0) { $0 | $1.observationBit }
            isMaskStale = false
        }
        return nil
    }
}

/// The listeners of one property, in subscription order. Most have exactly one, which needs no array.
///
/// Copyable, so notifying runs from a snapshot outside the lock. Cancelled listeners stay until
/// swept in a batch, so subscribing and releasing many listeners of one property stays linear.
struct _Subscribers {
    static let minimumSweepThreshold = 8

    private var first: _ListenerCore
    private var others: [_ListenerCore] = []
    /// Released listeners still in `others`.
    private var releasedCount = 0
    /// Size of `others` at which inserting first sweeps it; this also catches cancelled listeners
    /// that are never released, such as one-shot listeners that fired for another property.
    private var sweepThreshold = minimumSweepThreshold

    init(_ listener: _ListenerCore) {
        first = listener
    }

    var count: Int { 1 + others.count }

    mutating func insert(_ listener: _ListenerCore) {
        if others.count >= sweepThreshold {
            sweep()
            if first.isCancelled, !replaceFirst() {
                self = _Subscribers(listener)
                return
            }
        }
        others.append(listener)
    }

    /// Returns `true` if no listener remains; the value must then be discarded.
    mutating func remove(_ listener: _ListenerCore) -> Bool {
        if first === listener { return !replaceFirst() }
        if let index = others.firstIndex(where: { $0 === listener }) {
            others.remove(at: index)
        }
        return false
    }

    /// Releases a cancelled listener. Returns `true` if no listener remains.
    mutating func release(_ listener: _ListenerCore) -> Bool {
        if first === listener { return !replaceFirst() }
        releasedCount += 1
        if releasedCount * 2 > others.count { sweep() }
        return false
    }

    /// Returns `true` if no listener remains.
    mutating func removeCancelled() -> Bool {
        if !others.isEmpty { sweep() }
        return first.isCancelled && !replaceFirst()
    }

    /// Notifies all listeners. Returns whether a one-shot listener is now done.
    func notify() -> Bool {
        var hasFinishedListeners = first.notify()
        let others = others.span
        for index in others.indices where others[index].notify() {
            hasFinishedListeners = true
        }
        return hasFinishedListeners
    }

    /// Moves the last live listener into `first`. Returns `false` if there is none.
    private mutating func replaceFirst() -> Bool {
        while let next = others.popLast() {
            guard next.isCancelled else {
                first = next
                return true
            }
        }
        return false
    }

    private mutating func sweep() {
        others.removeAll { $0.isCancelled }
        releasedCount = 0
        sweepThreshold = max(Self.minimumSweepThreshold, 2 * others.count)
    }
}

extension PropertyID {
    /// The property's bit in the observed-index mask. Any identifier other than
    /// an index in `0..<64` uses all bits.
    @inlinable
    var observationBit: UInt64 {
        guard case let .index(index) = id, (0..<64).contains(index) else { return .max }
        return 1 << index
    }
}
