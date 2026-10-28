import Dispatch
import Synchronization
import Testing

@testable import Reactivity

struct OneShotOwnershipTests {
    @Test func releasesCallbackWhenRegistrarDiesWithoutNotification() {
        let count = OneShotLifetimeCount()
        var registrar: ReactivityRegistrar? = ReactivityRegistrar()
        do {
            let capture = OneShotCapture(count)
            withReactiveTracking {
                registrar!.access(PropertyID(0))
            } onChange: {
                capture.called()
            }
        }
        #expect(count.deaths.load(ordering: .relaxed) == 0)
        registrar = nil
        #expect(count.calls.load(ordering: .relaxed) == 0)
        #expect(count.deaths.load(ordering: .relaxed) == 1)
    }

    @Test(arguments: [false, true]) func retainsUntilLastRegistrarOrFirstNotification(notify: Bool) {
        let count = OneShotLifetimeCount()
        var first: ReactivityRegistrar? = ReactivityRegistrar()
        var second: ReactivityRegistrar? = ReactivityRegistrar()
        do {
            let capture = OneShotCapture(count)
            withReactiveTracking {
                first!.access(PropertyID(0))
                second!.access(PropertyID(0))
            } onChange: {
                capture.called()
            }
        }
        first = nil
        #expect(count.deaths.load(ordering: .relaxed) == 0)
        if notify {
            second!.willSet(PropertyID(0))
            second!.willSet(PropertyID(0))
            #expect(count.calls.load(ordering: .relaxed) == 1)
            #expect(count.deaths.load(ordering: .relaxed) == 1)
        }
        second = nil
        #expect(count.deaths.load(ordering: .relaxed) == 1)
    }

    @Test func simultaneousRegistrarsDeliverOnlyOnce() {
        let first = ReactivityRegistrar()
        let second = ReactivityRegistrar()
        let count = Atomic(0)
        withReactiveTracking {
            first.access(PropertyID(0))
            second.access(PropertyID(0))
        } onChange: {
            count.wrappingAdd(1, ordering: .relaxed)
        }
        DispatchQueue.concurrentPerform(iterations: 32) { index in
            (index.isMultiple(of: 2) ? first : second).willSet(PropertyID(0))
        }
        #expect(count.load(ordering: .relaxed) == 1)
    }

    @Test func noAccessDoesNotCreateHandler() {
        let creations = Atomic(0)
        func makeHandler() -> @Sendable () -> Void {
            creations.wrappingAdd(1, ordering: .relaxed)
            return {}
        }
        let result = withReactiveTracking({ 42 }, onChange: makeHandler())
        #expect(result == 42)
        #expect(creations.load(ordering: .relaxed) == 0)
    }
}

private final class OneShotLifetimeCount: Sendable {
    let calls = Atomic(0)
    let deaths = Atomic(0)
}
private final class OneShotCapture: Sendable {
    let count: OneShotLifetimeCount
    init(_ count: OneShotLifetimeCount) { self.count = count }
    func called() { count.calls.wrappingAdd(1, ordering: .relaxed) }
    deinit { count.deaths.wrappingAdd(1, ordering: .relaxed) }
}
