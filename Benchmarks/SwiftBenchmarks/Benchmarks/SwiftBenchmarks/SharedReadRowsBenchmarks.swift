import Benchmark
@_spi(Benchmarking) import ElementaryUI
import Reactivity

@Reactive
final class SharedReadStore {
    var rows: [BenchRow] = []
    var selectedID: String = ""
}

@View
struct SharedReadRowView {
    let row: BenchRow
    let isSelected: Bool

    var body: some View {
        tr(.class(isSelected ? "danger" : "")) {
            td { row.id }
            td { row.label }
        }
    }
}

@View
struct SharedReadRowsView {
    @Environment(SharedReadStore.self) var store: SharedReadStore

    var body: some View {
        tbody {
            ForEach(store.rows, id: \.id) { row in
                SharedReadRowView(row: row, isSelected: store.selectedID == row.id)
            }
        }
    }
}

func sharedReadRowsBenchmarks() {
    let rowCount = 1_000
    let firstRows = (0..<rowCount).map { BenchRow(id: "\($0)", label: "first-\($0)") }
    let secondRows = (rowCount..<2 * rowCount).map { BenchRow(id: "\($0)", label: "second-\($0)") }

    func withMounted(_ body: (SharedReadStore, NoOpInteractor) -> Void) {
        let store = SharedReadStore()
        let dom = NoOpInteractor()
        let mounted = Application(SharedReadRowsView().environment(store))._mount(dom: dom, root: dom.rootNode)
        dom.drain()
        body(store, dom)
        mounted.unmount()
        dom.drain()
    }

    Benchmark("ForEach.sharedRead.create", configuration: .init(tags: ["rows": "\(rowCount)"])) { benchmark in
        withMounted { store, dom in
            for _ in benchmark.scaledIterations {
                benchmark.startMeasurement()
                store.rows = firstRows
                dom.drain()
                benchmark.stopMeasurement()
                store.rows = []
                dom.drain()
            }
        }
    }

    Benchmark("ForEach.sharedRead.append", configuration: .init(tags: ["rows": "\(rowCount)"])) { benchmark in
        withMounted { store, dom in
            for _ in benchmark.scaledIterations {
                store.rows = firstRows
                dom.drain()
                benchmark.startMeasurement()
                store.rows.append(contentsOf: secondRows)
                dom.drain()
                benchmark.stopMeasurement()
                store.rows = []
                dom.drain()
            }
        }
    }

    Benchmark("ForEach.sharedRead.clear", configuration: .init(tags: ["rows": "\(rowCount)"])) { benchmark in
        withMounted { store, dom in
            for _ in benchmark.scaledIterations {
                store.rows = firstRows
                dom.drain()
                benchmark.startMeasurement()
                store.rows = []
                dom.drain()
                benchmark.stopMeasurement()
            }
        }
    }

    Benchmark("ForEach.sharedRead.select", configuration: .init(tags: ["rows": "\(rowCount)"])) { benchmark in
        withMounted { store, dom in
            store.rows = firstRows
            dom.drain()
            var toggle = false
            for _ in benchmark.scaledIterations {
                benchmark.startMeasurement()
                store.selectedID = toggle ? "0" : "999"
                dom.drain()
                benchmark.stopMeasurement()
                toggle.toggle()
            }
        }
    }
}
