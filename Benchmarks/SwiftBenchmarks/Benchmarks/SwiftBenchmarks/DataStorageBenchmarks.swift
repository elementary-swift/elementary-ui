import Benchmark
@_spi(Benchmarking) import ElementaryUI
import Reactivity

extension EnvironmentValues {
    @Entry var benchNumber: Int = 0
    @Entry var benchLabel: String = ""
}

@View
struct StateRowView {
    let id: Int
    @State var count: Int = 0
    @State var label: String = "row"
    @State var values: [Int] = []

    var body: some View {
        p { "\(id) \(count) \(label) \(values.count)" }
    }
}

@View
struct StateRowsView {
    let ids: [Int]

    var body: some View {
        ForEach(ids, id: \.self) { id in
            StateRowView(id: id)
        }
    }
}

@View
struct EnvironmentReaderView {
    @Environment(#Key(\.benchNumber)) var number
    @Environment(#Key(\.benchLabel)) var label

    var body: some View {
        p { "\(number) \(label)" }
    }
}

@View
struct EnvironmentRowsView {
    let ids: [Int]

    var body: some View {
        ForEach(ids, id: \.self) { id in
            EnvironmentReaderView()
                .environment(#Key(\.benchNumber), id)
                .environment(#Key(\.benchLabel), "row")
        }
    }
}

@View
struct EnvironmentDeepReadersView {
    let ids: [Int]

    var body: some View {
        div {
            ForEach(ids, id: \.self) { _ in
                EnvironmentReaderView()
            }
        }
        .environment(#Key(\.benchNumber), 1)
        .environment(#Key(\.benchLabel), "outer")
        .environment(#Key(\.benchNumber), 2)
        .environment(#Key(\.benchLabel), "outer2")
        .environment(#Key(\.benchNumber), 3)
        .environment(#Key(\.benchLabel), "outer3")
        .environment(#Key(\.benchNumber), 4)
        .environment(#Key(\.benchLabel), "outer4")
    }
}

func registerDataStorageBenchmarks() {
    let config = Benchmark.Configuration(
        metrics: [.instructions, .mallocCountTotal],
        units: [.instructions: .count, .mallocCountTotal: .count],
        warmupIterations: 3,
        scalingFactor: .one,
        maxDuration: .seconds(2),
        maxIterations: 100
    )

    let ids = Array(0..<1_000)

    Benchmark("State.mount.1000", configuration: config) { benchmark in
        for _ in benchmark.scaledIterations {
            let dom = NoOpInteractor()
            benchmark.startMeasurement()
            let mounted = Application(StateRowsView(ids: ids))._mount(dom: dom, root: dom.rootNode)
            dom.drain()
            benchmark.stopMeasurement()
            mounted.unmount()
            dom.drain()
        }
    }

    Benchmark("State.storage.readWrite.1000", configuration: config) { benchmark in
        let storage = StateRowView.__initializeState(from: StateRowView(id: 0))
        var view = StateRowView(id: 0)
        StateRowView.__restoreState(storage, in: &view)
        for _ in benchmark.scaledIterations {
            benchmark.startMeasurement()
            for _ in 0..<1000 {
                view.count += 1
                view.values.append(view.count)
            }
            benchmark.stopMeasurement()
            view.values.removeAll(keepingCapacity: true)
        }
        blackHole(view.count)
    }

    Benchmark("Environment.mount.1000", configuration: config) { benchmark in
        for _ in benchmark.scaledIterations {
            let dom = NoOpInteractor()
            benchmark.startMeasurement()
            let mounted = Application(EnvironmentRowsView(ids: ids))._mount(dom: dom, root: dom.rootNode)
            dom.drain()
            benchmark.stopMeasurement()
            mounted.unmount()
            dom.drain()
        }
    }

    Benchmark("Environment.mount.deepReaders.1000", configuration: config) { benchmark in
        for _ in benchmark.scaledIterations {
            let dom = NoOpInteractor()
            benchmark.startMeasurement()
            let mounted = Application(EnvironmentDeepReadersView(ids: ids))._mount(dom: dom, root: dom.rootNode)
            dom.drain()
            benchmark.stopMeasurement()
            mounted.unmount()
            dom.drain()
        }
    }
}
