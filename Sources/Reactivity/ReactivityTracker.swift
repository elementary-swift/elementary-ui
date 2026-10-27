import Synchronization

/// The listeners subscribed to the properties of one registrar.
///
/// A write first checks a bitmask of the property indices that may be observed,
/// so writes to unobserved properties don't take the lock.
final class ReactivityTracker: Sendable {
    private let table = Mutex(_SubscriptionTable())
    private let observedMask = Atomic<UInt64>(0)

    func subscribe(_ listener: _ListenerCore, to property: PropertyID) {
        updateTable { $0.insert(listener, for: property) }
    }

    func unsubscribe(_ listener: _ListenerCore, from property: PropertyID) {
        updateTable { $0.remove(for: property) { $0 === listener } }
    }

    func notify(_ property: PropertyID) {
        guard observedMask.load(ordering: .relaxed) & property.observationBit != 0 else { return }
        notifyListeners(of: property)
    }

    // Keeps the rarely taken path out of every property setter.
    @inline(never)
    private func notifyListeners(of property: PropertyID) {
        guard let listeners = updateTable({ $0.listeners(for: property) }) else { return }
        if listeners.notify() {
            updateTable { $0.remove(for: property) { $0.isCancelled } }
        }
    }

    func updateTable<Result>(_ body: (inout _SubscriptionTable) -> Result) -> Result {
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
    private var subscribers: [PropertyID: _Subscribers] = [:]

    /// A superset of the observed property indices. Subscribing adds bits right away.
    /// Unsubscribing only marks the mask stale; it is narrowed on the next missed write.
    private(set) var mask: UInt64 = 0
    private var isMaskStale = false

    fileprivate mutating func insert(_ listener: _ListenerCore, for property: PropertyID) {
        if let index = subscribers.index(forKey: property) {
            subscribers.values[index].insert(listener)
        } else {
            subscribers[property] = _Subscribers(listener)
        }
        mask |= property.observationBit
    }

    fileprivate mutating func remove(for property: PropertyID, where shouldRemove: (_ListenerCore) -> Bool) {
        guard let index = subscribers.index(forKey: property) else { return }
        if !subscribers.values[index].remove(where: shouldRemove) {
            subscribers.remove(at: index)
        }
        isMaskStale = true
    }

    mutating func listeners(for property: PropertyID) -> _Subscribers? {
        if let listeners = subscribers[property] { return listeners }
        if isMaskStale {
            mask = subscribers.keys.reduce(0) { $0 | $1.observationBit }
            isMaskStale = false
        }
        return nil
    }
}

/// The listeners of one property. Most properties have exactly one, which needs no array.
struct _Subscribers {
    private var first: _ListenerCore
    private var others: [_ListenerCore] = []

    init(_ listener: _ListenerCore) {
        first = listener
    }

    /// Adds a listener, dropping finished one-shot listeners.
    mutating func insert(_ listener: _ListenerCore) {
        if remove(where: { $0.isCancelled }) {
            others.append(listener)
        } else {
            self = _Subscribers(listener)
        }
    }

    /// Returns whether any listener remains.
    mutating func remove(where shouldRemove: (_ListenerCore) -> Bool) -> Bool {
        if !others.isEmpty { others.removeAll(where: shouldRemove) }
        guard shouldRemove(first) else { return true }
        guard let next = others.popLast() else { return false }
        first = next
        return true
    }

    var count: Int { 1 + others.count }

    /// Notifies all listeners. Returns whether a one-shot listener is now done.
    func notify() -> Bool {
        var hasFinishedListeners = first.notify()
        for listener in others where listener.notify() {
            hasFinishedListeners = true
        }
        return hasFinishedListeners
    }
}

extension PropertyID {
    /// The property's bit in the observed-index mask. Any identifier other than
    /// an index in `0..<64` uses all bits.
    var observationBit: UInt64 {
        guard case let .index(index) = id, (0..<64).contains(index) else { return .max }
        return 1 << index
    }
}
