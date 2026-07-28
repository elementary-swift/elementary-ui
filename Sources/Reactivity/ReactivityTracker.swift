import BasicContainers

struct ReactivityTracker: Sendable {
    private struct Subscription: Sendable {
        private enum Kind {
            case willSet(@Sendable (PropertyID) -> Void)
            case didSet(@Sendable (PropertyID) -> Void)
        }

        private var kind: Kind
        var properties: Set<PropertyID>

        static func willSetTracking(of properties: Set<PropertyID>, closure: @Sendable @escaping (PropertyID) -> Void) -> Self {
            Self(kind: .willSet(closure), properties: properties)
        }

        static func didSetTracking(of properties: Set<PropertyID>, closure: @Sendable @escaping (PropertyID) -> Void) -> Self {
            Self(kind: .didSet(closure), properties: properties)
        }

        var willSetTracker: (@Sendable (PropertyID) -> Void)? {
            switch kind {
            case let .willSet(tracker):
                return tracker
            default:
                return nil
            }
        }

        var didSetTracker: (@Sendable (PropertyID) -> Void)? {
            switch kind {
            case let .didSet(tracker):
                return tracker
            default:
                return nil
            }
        }
    }

    private struct State: ~Copyable, Sendable {
        private var usedSubscriptionIDs: UInt64 = 0
        private var nextOverflowSubscriptionID = 64
        private var subscriptions = UniqueArray<Subscription?>()
        private var freeOverflowSubscriptionIDs = UniqueArray<Int>()
        private var trackedProperties = [PropertyID: Set<Int>]()

        private mutating func generateSubscriptionID() -> Int {
            let available = (~usedSubscriptionIDs).trailingZeroBitCount
            if available < UInt64.bitWidth {
                usedSubscriptionIDs |= 1 << available
                return available
            }

            if let available = freeOverflowSubscriptionIDs.popLast() {
                return available
            }

            defer { nextOverflowSubscriptionID &+= 1 }
            return nextOverflowSubscriptionID
        }

        mutating func registerSubscription(_ subscription: Subscription) -> Int {
            let id = generateSubscriptionID()
            if id < subscriptions.count {
                subscriptions[id] = subscription
            } else {
                assert(id == subscriptions.count)
                subscriptions.append(subscription)
            }
            for property in subscription.properties {
                trackedProperties[property, default: []].insert(id)
            }
            return id
        }

        mutating func actionsFor(willSet: PropertyID) -> [@Sendable (PropertyID) -> Void] {
            var trackers = [@Sendable (PropertyID) -> Void]()
            if let ids = trackedProperties[willSet] {
                for id in ids {
                    if let tracker = subscriptions[id]?.willSetTracker {
                        trackers.append(tracker)
                    }
                }
            }
            return trackers
        }

        mutating func actionsFor(didSet: PropertyID) -> [@Sendable (PropertyID) -> Void] {
            var trackers = [@Sendable (PropertyID) -> Void]()
            if let ids = trackedProperties[didSet] {
                for id in ids {
                    if let tracker = subscriptions[id]?.didSetTracker {
                        trackers.append(tracker)
                    }
                }
            }
            return trackers
        }

        mutating func cancel(_ id: Int) {
            guard subscriptions.indices.contains(id),
                let observation = subscriptions[id].take()
            else { return }

            if id < UInt64.bitWidth {
                usedSubscriptionIDs &= ~(1 << id)
            } else {
                freeOverflowSubscriptionIDs.append(id)
            }
            for property in observation.properties {
                if let index = trackedProperties.index(forKey: property) {
                    trackedProperties.values[index].remove(id)
                    if trackedProperties.values[index].isEmpty {
                        trackedProperties.remove(at: index)
                    }
                }
            }
        }

        mutating func cancelAll() {
            usedSubscriptionIDs = 0
            nextOverflowSubscriptionID = UInt64.bitWidth
            subscriptions.removeAll()
            freeOverflowSubscriptionIDs.removeAll()
            trackedProperties.removeAll()
        }
    }

    private let state = MutexBox(State())

    var id: ObjectIdentifier { state.id }

    func registerTracking(for properties: Set<PropertyID>, willSet observer: @Sendable @escaping (PropertyID) -> Void) -> SubscriptionToken
    {
        let id = state.withLock { $0.registerSubscription(.willSetTracking(of: properties, closure: observer)) }
        return SubscriptionToken(id: id, tracker: self)
    }

    func registerTracking(for properties: Set<PropertyID>, didSet observer: @Sendable @escaping (PropertyID) -> Void) -> SubscriptionToken {
        let id = state.withLock { $0.registerSubscription(.didSetTracking(of: properties, closure: observer)) }
        return SubscriptionToken(id: id, tracker: self)
    }

    func willSet(property: PropertyID) {
        let actions = state.withLock { $0.actionsFor(willSet: property) }
        for action in actions {
            action(property)
        }
    }

    func didSet(property: PropertyID) {
        let actions = state.withLock { $0.actionsFor(didSet: property) }
        for action in actions {
            action(property)
        }
    }

    func cancelAll() {
        state.withLock { $0.cancelAll() }
    }

    private func cancel(_ id: Int) {
        state.withLock { $0.cancel(id) }
    }
}

extension ReactivityTracker {
    struct SubscriptionToken {
        private let id: Int
        private let tracker: ReactivityTracker

        fileprivate init(id: Int, tracker: ReactivityTracker) {
            self.id = id
            self.tracker = tracker
        }

        consuming func cancel() {
            tracker.cancel(id)
        }
    }
}
