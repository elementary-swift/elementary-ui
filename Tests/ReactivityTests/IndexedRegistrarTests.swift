import Synchronization
import Testing

@testable import Reactivity

@Suite struct IndexedRegistrarTests {
    @Test func reactivePropertiesUseTheirIndexAsIdentity() {
        let model = IndexedModel()
        let changes = Atomic(0)
        var listener = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
        _ = listener.track { model.second }
        #expect(model.tracker.withTable { $0.mask } == 1 << 1)
        model.first += 1  // index 0: skipped without taking the lock
        model.second += 1
        #expect(changes.load(ordering: .relaxed) == 1)
    }

    @Test func unobservedIndicesSkipAgainAfterUnsubscribing() {
        let registrar = ReactivityRegistrar()
        var listener = ReactiveTracking.Listener {}
        listener.track { registrar.access(PropertyID(1)) }
        listener.track { registrar.access(PropertyID(2)) }
        registrar.willSet(PropertyID(1))  // a miss narrows the stale mask
        #expect(registrar.tracker.withTable { $0.mask } == 1 << 2)
    }

    @Test func otherIdentifiersAlwaysTakeTheSlowPath() {
        for property in [PropertyID(-1), PropertyID(64), PropertyID("named")] {
            let registrar = ReactivityRegistrar()
            let changes = Atomic(0)
            var listener = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
            listener.track { registrar.access(property) }
            #expect(registrar.tracker.withTable { $0.mask } == .max)
            registrar.willSet(PropertyID(3))
            registrar.willSet(property)
            #expect(changes.load(ordering: .relaxed) == 1)
        }
    }

    @Test func tracksPropertiesBeyondMaskCapacity() {
        let registrar = ReactivityRegistrar()
        let changes = Atomic(0)
        var listener: ReactiveTracking.Listener? = ReactiveTracking.Listener { changes.wrappingAdd(1, ordering: .relaxed) }
        listener!.track {
            for index in 0..<100 { registrar.access(PropertyID(index)) }
        }
        for index in 0..<100 { registrar.willSet(PropertyID(index)) }
        #expect(changes.load(ordering: .relaxed) == 100)
        listener = nil
        for index in 0..<100 { registrar.willSet(PropertyID(index)) }
        #expect(changes.load(ordering: .relaxed) == 100)
    }

    @Test func inheritedClassesUseIndependentRegistrars() {
        let model = IndexedChild()
        let base = Atomic(0)
        let child = Atomic(0)
        withReactiveTracking {
            _ = model.base
        } onChange: {
            base.wrappingAdd(1, ordering: .relaxed)
        }
        withReactiveTracking {
            _ = model.child
        } onChange: {
            child.wrappingAdd(1, ordering: .relaxed)
        }
        model.child += 1
        #expect(base.load(ordering: .relaxed) == 0)
        model.base += 1
        #expect(base.load(ordering: .relaxed) == 1)
        #expect(child.load(ordering: .relaxed) == 1)
    }
}

@Reactive private final class IndexedModel {
    var first = 0
    var second = 0
    @ReactiveIgnored var tracker: ReactivityTracker { _$reactivity.tracker }
}
@Reactive private class IndexedBase { var base = 0 }
@Reactive private final class IndexedChild: IndexedBase { var child = 0 }
