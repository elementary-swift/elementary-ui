import Reactivity
import Synchronization
import Testing

@Suite
struct ReactiveClassesTests {
    @Test
    func tracksChanges() {
        let foo = Foo()
        let tracker = ChangeTracker()

        withReactiveTracking {
            _ = foo.one
        } onChange: {
            tracker.hasChanged = true
        }

        foo.two = "test"
        #expect(!tracker.hasChanged)
        foo.one = "test"
        #expect(tracker.hasChanged)
    }

    @Test
    func tracksChangesInParellel() async {
        await withTaskGroup { group in
            for _ in 0..<1000 {
                group.addTask {
                    let foo = Foo()
                    let tracker = ChangeTracker()
                    await Task.yield()
                    withReactiveTracking {
                        _ = foo.one
                    } onChange: {
                        tracker.hasChanged = true
                    }
                    await Task.yield()
                    foo.two = "test"
                    await Task.yield()
                    #expect(!tracker.hasChanged)
                    await Task.yield()
                    foo.one = "test"
                    #expect(tracker.hasChanged)
                }
            }
        }

    }

    @Test
    func tracksMoreThanBitmapCapacityAndReusesIDs() {
        let foo = Foo()
        let changeCount = Atomic(0)

        for batch in 1...20 {
            for _ in 0..<80 {
                withReactiveTracking {
                    _ = foo.one
                } onChange: {
                    changeCount.wrappingAdd(1, ordering: .relaxed)
                }
            }

            foo.one = "\(batch)"
            #expect(changeCount.load(ordering: .relaxed) == batch * 80)
        }
    }

    @Test
    func nestedTrackingInstallsBothObservers() {
        let foo = Foo()
        let outerChanged = Atomic(false)
        let innerChanged = Atomic(false)

        withReactiveTracking {
            withReactiveTracking {
                _ = foo.one
            } onChange: {
                innerChanged.store(true, ordering: .relaxed)
            }
        } onChange: {
            outerChanged.store(true, ordering: .relaxed)
        }

        foo.one = "changed"
        let didChangeInner = innerChanged.load(ordering: .relaxed)
        let didChangeOuter = outerChanged.load(ordering: .relaxed)
        #expect(didChangeInner)
        #expect(didChangeOuter)
    }
}

final class ChangeTracker: Sendable {
    private let _hasChanged = Atomic(false)

    var hasChanged: Bool {
        get {
            _hasChanged.load(ordering: .relaxed)
        }
        set {
            _hasChanged.store(newValue, ordering: .relaxed)
        }
    }
}

@Reactive
class Foo {
    var one: String = ""
    var two: String = ""
}
