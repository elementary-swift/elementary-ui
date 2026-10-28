import Benchmark
@_spi(Benchmarking) import ElementaryUI
import Reactivity
import Synchronization

@Reactive final class ReactivityBenchModel {
    var value = 0
    var other = 0
}
final class ReactivityBenchCount: Sendable { let value = Atomic(0) }
final class ReactivityBurstStore {
    let models: [ReactivityBenchModel]
    init(_ count: Int) { models = (0..<count).map { _ in ReactivityBenchModel() } }
}
@View struct ReactivityBurstView {
    let store: ReactivityBurstStore
    var body: some View {
        let sum = store.models.reduce(0) { $0 + $1.value }
        p { "\(sum)" }
    }
}

func registerReactivityBenchmarks() {
    // Each sample contains 1,000 identical logical operations. No timing metrics.
    let config = Benchmark.Configuration(
        metrics: [.instructions, .mallocCountTotal],
        units: [.instructions: .count, .mallocCountTotal: .count],
        warmupIterations: 3,
        scalingFactor: .one,
        maxDuration: .seconds(2),
        maxIterations: 100
    )

    Benchmark("Reactivity.neverObserved.1000", configuration: config) { benchmark in
        let model = ReactivityBenchModel()
        model.value = 0  // prime the accessor before measuring the steady state
        benchmark.startMeasurement()
        for _ in 0..<1000 { model.value += 1 }
        benchmark.stopMeasurement()
        precondition(model.value == 1000)
        blackHole(model)
    }
    Benchmark("Reactivity.unobservedProperty.1000", configuration: config) { benchmark in
        let model = ReactivityBenchModel()
        model.other = 0
        withReactiveTracking {
            _ = model.value
        } onChange: {
            preconditionFailure("Unexpected change")
        }
        model.other = 0  // establish the unobserved index after observation begins
        benchmark.startMeasurement()
        for _ in 0..<1000 { model.other += 1 }
        benchmark.stopMeasurement()
        precondition(model.other == 1000)
        blackHole(model)
    }
    Benchmark("Reactivity.observedMutation.1000", configuration: config) { benchmark in
        let models = (0..<1000).map { _ in ReactivityBenchModel() }
        let count = ReactivityBenchCount()
        for model in models {
            withReactiveTracking {
                _ = model.value
            } onChange: {
                count.value.wrappingAdd(1, ordering: .relaxed)
            }
        }
        benchmark.startMeasurement()
        for model in models { model.value += 1 }
        benchmark.stopMeasurement()
        precondition(count.value.load(ordering: .relaxed) == 1000)
        blackHole(models)
    }
    Benchmark("Reactivity.trackAndInvalidate.1000", configuration: config) { benchmark in
        let model = ReactivityBenchModel()
        let count = ReactivityBenchCount()
        benchmark.startMeasurement()
        for _ in 0..<1000 {
            withReactiveTracking {
                _ = model.value
            } onChange: {
                count.value.wrappingAdd(1, ordering: .relaxed)
            }
            model.value += 1
        }
        benchmark.stopMeasurement()
        precondition(count.value.load(ordering: .relaxed) == 1000)
        blackHole(model)
    }
    Benchmark("Reactivity.rerender.1000", configuration: config) { benchmark in
        // One view re-rendered after each write: persistent re-tracking of a stable dependency.
        let store = ReactivityBurstStore(1)
        let dom = NoOpInteractor()
        let app = Application(ReactivityBurstView(store: store))._mount(dom: dom, root: dom.rootNode)
        dom.drain()
        store.models[0].value += 1
        dom.drain()
        benchmark.startMeasurement()
        for _ in 0..<1000 {
            store.models[0].value += 1
            dom.drain()
        }
        benchmark.stopMeasurement()
        precondition(store.models[0].value == 1001)
        app.unmount()
        dom.drain()
    }
    for size in [100, 1600] {
        Benchmark("Reactivity.renderBurst.\(size)", configuration: config) { benchmark in
            let store = ReactivityBurstStore(size)
            let dom = NoOpInteractor()
            let app = Application(ReactivityBurstView(store: store))._mount(dom: dom, root: dom.rootNode)
            dom.drain()
            // Warm the installed dependency set through one complete UI update.
            for model in store.models { model.value += 1 }
            dom.drain()
            benchmark.startMeasurement()
            for model in store.models { model.value += 1 }
            dom.drain()
            benchmark.stopMeasurement()
            precondition(store.models.allSatisfy { $0.value == 2 })
            app.unmount()
            dom.drain()
        }
    }
}
