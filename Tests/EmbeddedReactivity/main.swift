import Reactivity

// Exercises the public API only; listeners are package API and covered by the native tests.

@Reactive final class Model {
    var value = 0
    var other = 0
}

final class Counter: @unchecked Sendable {
    var calls = 0
    var deaths = 0
}

final class Capture: Sendable {
    let counter: Counter
    init(_ counter: Counter) { self.counter = counter }
    func called() { counter.calls += 1 }
    deinit { counter.deaths += 1 }
}

@inline(never)
func checkIndexedMacroProperties() {
    let model = Model()
    let changes = Counter()
    withReactiveTracking {
        _ = model.value
    } onChange: {
        changes.calls += 1
    }
    // Plain assignments: inlining the indexed `_modify` accessor into a function crashes
    // the Swift 6.4 Embedded optimizer (MandatoryPerformanceOptimizations).
    model.other = 1  // unobserved index: skipped without taking the lock
    precondition(changes.calls == 0)
    model.value = 1
    model.value = 2  // one-shot: already fired
    precondition(changes.calls == 1)
}

@inline(never)
func checkOneShotClaimsBeforeRecursiveMutation() {
    let once = Counter()
    let registrar = ReactivityRegistrar()
    withReactiveTracking {
        registrar.access(PropertyID(0))
    } onChange: {
        once.calls += 1
        registrar.willSet(PropertyID(0))  // the registration must already be cancelled
    }
    registrar.willSet(PropertyID(0))
    precondition(once.calls == 1)
}

@inline(never)
func checkOneShotReleasedWithRegistrar() {
    let counter = Counter()
    trackUntilRegistrarDrops(counter)
    precondition(counter.calls == 0)
    precondition(counter.deaths == 1)
}

@inline(never)
func trackUntilRegistrarDrops(_ counter: Counter) {
    let registrar = ReactivityRegistrar()
    do {
        let capture = Capture(counter)
        withReactiveTracking {
            registrar.access(PropertyID(0))
        } onChange: {
            capture.called()
        }
    }
    withExtendedLifetime(registrar) {
        precondition(counter.deaths == 0)
    }
}

checkIndexedMacroProperties()
checkOneShotClaimsBeforeRecursiveMutation()
checkOneShotReleasedWithRegistrar()
print("Embedded Reactivity smoke passed")
