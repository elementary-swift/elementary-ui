import Dispatch
import Synchronization
import Testing

@testable import Reactivity

@Suite
struct ListenerTests {
    @Test func notifiesBeforeEachChangeUntilDropped() {
        let model = ListenerModel()
        let changes = Atomic(0)
        var listener: ReactiveTracking.Listener? = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
        _ = listener!.track { model.one }
        model.two = "untracked"
        for _ in 0..<3 { model.one = "tracked" }
        #expect(changes.load(ordering: .relaxed) == 3)
        listener = nil
        model.one = "dropped"
        #expect(changes.load(ordering: .relaxed) == 3)
    }

    @Test func cancelledListenerIsNotNotified() {
        let model = ListenerModel()
        let changes = Atomic(0)
        var listener = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
        _ = listener.track { model.one }
        model.one = "tracked"
        listener.cancel()
        model.one = "cancelled"
        #expect(changes.load(ordering: .relaxed) == 1)
    }

    @Test func replacesDependenciesAndHandlesEmptyTracking() {
        let a = ListenerModel()
        let b = ListenerModel()
        let changes = Atomic(0)
        var listener = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
        listener.track {
            _ = a.one; _ = a.two
        }
        listener.track {
            _ = a.two; _ = b.one
        }
        a.one = "old"
        b.two = "other"
        #expect(changes.load(ordering: .relaxed) == 0)
        a.two = "new"
        b.one = "new"
        #expect(changes.load(ordering: .relaxed) == 2)
        listener.track {}
        a.two = "removed"
        b.one = "removed"
        #expect(changes.load(ordering: .relaxed) == 2)
    }

    @Test func joinsNestedScopes() {
        let model = ListenerModel()
        let a = Atomic(0)
        let b = Atomic(0)
        let c = Atomic(0)
        var outer = ReactiveTracking.Listener { a.wrappingAdd(1, ordering: .relaxed) }
        var inner = ReactiveTracking.Listener { b.wrappingAdd(1, ordering: .relaxed) }
        withReactiveTracking {
            outer.track { inner.track { _ = model.one } }
        } onChange: {
            c.wrappingAdd(1, ordering: .relaxed)
        }
        model.one = "nested"
        #expect(a.load(ordering: .relaxed) == 1)
        #expect(b.load(ordering: .relaxed) == 1)
        #expect(c.load(ordering: .relaxed) == 1)
    }

    @Test func droppingAllowsRunningCallbackToFinish() {
        let registrar = ReactivityRegistrar()
        let entered = DispatchSemaphore(value: 0)
        let finish = DispatchSemaphore(value: 0)
        let completed = DispatchGroup()
        let changes = Atomic(0)
        let owner = ListenerOwner()
        owner.listener = ReactiveTracking.Listener {
            changes.wrappingAdd(1, ordering: .relaxed)
            entered.signal()
            finish.wait()
        }
        owner.listener!.track { registrar.access(PropertyID(0)) }
        completed.enter()
        DispatchQueue.global().async {
            registrar.willSet(PropertyID(0))
            completed.leave()
        }
        entered.wait()
        owner.listener = nil
        registrar.willSet(PropertyID(0))
        finish.signal()
        completed.wait()
        #expect(changes.load(ordering: .relaxed) == 1)
    }

    @Test func canDropInsideHandler() {
        let model = ListenerModel()
        let owner = ListenerOwner()
        let changes = Atomic(0)
        owner.listener = ReactiveTracking.Listener {
            changes.wrappingAdd(1, ordering: .relaxed)
            owner.listener = nil
        }
        _ = owner.listener!.track { model.one }
        model.one = "drop"
        model.one = "ignored"
        #expect(changes.load(ordering: .relaxed) == 1)
    }

    @Test func droppedListenersInANotificationInProgressAreNotCalled() {
        let registrar = ReactivityRegistrar()
        let first = ListenerOwner()
        let second = ListenerOwner()
        let changes = Atomic(0)
        let handler: @Sendable () -> Void = {
            changes.wrappingAdd(1, ordering: .relaxed)
            first.listener = nil
            second.listener = nil
        }
        first.listener = ReactiveTracking.Listener(onChange: handler)
        second.listener = ReactiveTracking.Listener(onChange: handler)
        first.listener!.track { registrar.access(PropertyID(0)) }
        second.listener!.track { registrar.access(PropertyID(0)) }
        registrar.willSet(PropertyID(0))
        registrar.willSet(PropertyID(0))
        #expect(changes.load(ordering: .relaxed) == 1)
    }

    @Test func trackWithoutReadsReturnsNoDependencies() {
        let model = ListenerModel()
        var dependencies: ReactiveTracking.AccessedDependencies?
        let value = ReactiveTracking.track(into: &dependencies) { 42 }
        #expect(value == 42)
        let hasDependencies = dependencies != nil
        #expect(!hasDependencies)
        _ = ReactiveTracking.track(into: &dependencies) { model.one }
        let hasTrackedDependencies = dependencies != nil
        #expect(hasTrackedDependencies)
    }

    @Test func listenerAdoptsTrackedDependenciesWithoutRerunning() {
        let model = ListenerModel()
        let changes = Atomic(0)
        var runs = 0
        var dependencies: ReactiveTracking.AccessedDependencies?
        _ = ReactiveTracking.track(into: &dependencies) {
            runs += 1
            return model.one
        }
        var listener: ReactiveTracking.Listener? = ReactiveTracking.Listener(tracking: dependencies.take()!) {
            changes.wrappingAdd(1, ordering: .relaxed)
        }
        #expect(runs == 1)
        model.two = "untracked"
        model.one = "tracked"
        #expect(changes.load(ordering: .relaxed) == 1)
        listener = nil
        model.one = "dropped"
        #expect(changes.load(ordering: .relaxed) == 1)
    }

    @Test func retrackingTransitionsSubscriptions() {
        let a = ListenerModel()
        let b = ListenerModel()
        let changes = Atomic(0)
        var listener = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
        listener.track { _ = (a.one, b.one) }
        listener.track { _ = (a.one, b.two) }  // keeps a.one, swaps b.one for b.two
        b.one = "dropped"
        #expect(changes.load(ordering: .relaxed) == 0)
        a.one = "kept"
        b.two = "added"
        #expect(changes.load(ordering: .relaxed) == 2)
    }

    @Test func listenerCanOutliveItsModel() {
        var model: ListenerModel? = ListenerModel()
        var listener = ReactiveTracking.Listener {}
        _ = listener.track { model!.one }
        model = nil
        listener.track {}  // unsubscribing from a released registrar is safe
    }

    @Test func oneShotScopeInsideListenerKeepsBothDependencies() {
        let registrar = ReactivityRegistrar()
        let persistent = Atomic(0)
        let once = Atomic(0)
        var listener = ReactiveTracking.Listener { persistent.wrappingAdd(1, ordering: .relaxed) }
        listener.track {
            withReactiveTracking {
                registrar.access(PropertyID(0))
            } onChange: {
                once.wrappingAdd(1, ordering: .relaxed)
            }
            registrar.access(PropertyID(1))
        }
        registrar.willSet(PropertyID(0))
        registrar.willSet(PropertyID(1))
        #expect(persistent.load(ordering: .relaxed) == 2)
        #expect(once.load(ordering: .relaxed) == 1)
    }

    @Test func oneShotClaimsConcurrentNotificationsOnlyOnce() {
        let registrar = ReactivityRegistrar()
        let changes = Atomic(0)
        withReactiveTracking {
            registrar.access(PropertyID(0))
        } onChange: {
            changes.wrappingAdd(1, ordering: .relaxed)
        }
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            registrar.willSet(PropertyID(0))
        }
        #expect(changes.load(ordering: .relaxed) == 1)
    }

    @Test func oneShotClaimsBeforeRecursiveMutation() {
        let registrar = ReactivityRegistrar()
        let changes = Atomic(0)
        withReactiveTracking {
            registrar.access(PropertyID(0))
        } onChange: {
            changes.wrappingAdd(1, ordering: .relaxed)
            registrar.willSet(PropertyID(0))
        }
        registrar.willSet(PropertyID(0))
        #expect(changes.load(ordering: .relaxed) == 1)
    }

    @Test func firedOneShotsDoNotAccumulateOnOtherProperties() {
        let registrar = ReactivityRegistrar()
        for _ in 0..<10 {
            withReactiveTracking {
                registrar.access(PropertyID(0))
                registrar.access(PropertyID(1))
            } onChange: {
            }
            registrar.willSet(PropertyID(0))  // fires; the subscription to 1 stays until replaced
        }
        let remaining = registrar.tracker.withTable { $0.listeners(for: PropertyID(1))?.count }
        // Fired one-shots are swept in batches, so they stay bounded.
        #expect(remaining! <= _Subscribers.minimumSweepThreshold + 1)
    }

    @Test func manyListenersOfOnePropertyNotifyOnlyLiveOnes() {
        let registrar = ReactivityRegistrar()
        let changes = Atomic(0)
        var listeners: [ListenerOwner] = []
        for _ in 0..<1000 {
            let owner = ListenerOwner()
            owner.listener = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
            owner.listener!.track { registrar.access(PropertyID(0)) }
            listeners.append(owner)
        }
        for index in listeners.indices where index.isMultiple(of: 2) {
            listeners[index].listener = nil
        }
        registrar.willSet(PropertyID(0))
        #expect(changes.load(ordering: .relaxed) == 500)

        listeners.removeAll()
        let remaining = registrar.tracker.withTable { $0.listeners(for: PropertyID(0)) }
        #expect(remaining == nil)
    }

    @Test func tracksMoreAccessesThanFitInline() {
        let registrar = ReactivityRegistrar()
        let changes = Atomic(0)
        var listener = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
        listener.track { for index in 0..<10 { registrar.access(PropertyID(index)) } }
        registrar.willSet(PropertyID(9))
        #expect(changes.load(ordering: .relaxed) == 1)

        // Drops 0..<7, keeps 7..<10, adds 10 and 11.
        listener.track { for index in 7..<12 { registrar.access(PropertyID(index)) } }
        registrar.willSet(PropertyID(0))
        registrar.willSet(PropertyID(5))
        #expect(changes.load(ordering: .relaxed) == 1)
        registrar.willSet(PropertyID(7))
        registrar.willSet(PropertyID(11))
        #expect(changes.load(ordering: .relaxed) == 3)

        _ = consume listener
        registrar.willSet(PropertyID(8))
        #expect(changes.load(ordering: .relaxed) == 3)
        #expect(registrar.tracker.withTable { $0.listeners(for: PropertyID(8)) } == nil)
    }
}

private final class ListenerOwner: @unchecked Sendable {
    var listener: ReactiveTracking.Listener?
}

@Reactive private final class ListenerModel: @unchecked Sendable {
    var one = ""
    var two = ""
}
