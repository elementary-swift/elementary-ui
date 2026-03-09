import Benchmark
@_spi(Benchmarking) import ElementaryUI
import Reactivity

struct BenchRow: Equatable {
    let id: Int
    var label: String
}

@Reactive
final class BenchStore {
    var rows: [BenchRow] = []
    func setRows(_ rows: [BenchRow]) { self.rows = rows }
    func append(_ rows: [BenchRow]) { self.rows.append(contentsOf: rows) }
    func removeLast(_ count: Int) {
        guard count > 0 else { return }
        rows.removeLast(count)
    }
    func removeMiddle() {
        guard !rows.isEmpty else { return }
        rows.remove(at: rows.count / 2)
    }
    func swapRows() {
        guard rows.count > 3 else { return }
        rows.swapAt(1, rows.count - 2)
    }
}

@View
struct BenchRowView {
    let row: BenchRow

    var body: some View {
        tr {
            td(.class("id")) { "\(row.id)" }
            td(.class("label")) { row.label }
        }
    }
}

@View
struct BenchAppView {
    @Environment(BenchStore.self) var store: BenchStore

    var body: some View {
        table(.class("bench-table")) {
            tbody {
                ForEach(store.rows, key: { $0.id }) { row in
                    BenchRowView(row: row)
                }
            }
        }
    }
}

@View
struct BenchLiteAppView {
    @Environment(BenchStore.self) var store: BenchStore

    var body: some View {
        ForEach(store.rows, key: { $0.id }) { _ in
            EmptyHTML()
        }
    }
}

private func makeRows(startID: Int, count: Int, labelPrefix: String) -> [BenchRow] {
    var rows: [BenchRow] = []
    rows.reserveCapacity(count)
    for i in 0..<count {
        rows.append(.init(id: startID + i, label: "\(labelPrefix)-\(i)"))
    }
    return rows
}

@inline(never)
private func withMountedList(
    initialRows: [BenchRow],
    _ body: (BenchStore, NoOpInteractor) -> Void
) {
    let store = BenchStore()
    store.setRows(initialRows)
    let dom = NoOpInteractor()
    let mounted = Application(BenchAppView().environment(store))._mount(dom: dom, root: dom.rootNode)
    dom.drain()  // flush initial mount before measured work

    body(store, dom)

    mounted.unmount()
    dom.drain()  // flush queued teardown work so next benchmark starts clean
}

@inline(never)
private func withMountedLiteList(
    initialRows: [BenchRow],
    _ body: (BenchStore, NoOpInteractor) -> Void
) {
    let store = BenchStore()
    store.setRows(initialRows)
    let dom = NoOpInteractor()
    let mounted = Application(BenchLiteAppView().environment(store))._mount(dom: dom, root: dom.rootNode)
    dom.drain()  // flush initial mount before measured work

    body(store, dom)

    mounted.unmount()
    dom.drain()  // flush queued teardown work so next benchmark starts clean
}

@MainActor
let benchmarks = {
    let rowCounts = [10, 1_000]

    for rowCount in rowCounts {
        let deltaCount = max(1, rowCount / 10)
        let emptyRows: [BenchRow] = []
        let baseRows = makeRows(startID: 0, count: rowCount, labelPrefix: "base-\(rowCount)")
        let baseRowsCopy = Array(baseRows)
        let reversedRows = Array(baseRows.reversed())
        let relabeledRows = baseRows.enumerated().map { index, row in
            BenchRow(id: row.id, label: "relabeled-\(rowCount)-\(index)")
        }
        let plusDeltaRows = makeRows(startID: 0, count: rowCount + deltaCount, labelPrefix: "plus-\(rowCount)")
        let addRows = Array(plusDeltaRows.suffix(deltaCount))

        Benchmark(
            "KeyedNode.patch.addAll",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedList(initialRows: emptyRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.setRows(baseRows)
                    dom.drain()
                    benchmark.stopMeasurement()

                    store.setRows(emptyRows)
                    dom.drain()
                }
            }
        }

        Benchmark(
            "KeyedNode.patch.removeAll",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedList(initialRows: baseRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.setRows(emptyRows)
                    dom.drain()
                    benchmark.stopMeasurement()

                    store.setRows(baseRows)
                    dom.drain()
                }
            }
        }

        Benchmark(
            "KeyedNode.patch.add10Percent",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedList(initialRows: baseRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.append(addRows)
                    dom.drain()
                    benchmark.stopMeasurement()

                    store.removeLast(deltaCount)
                    dom.drain()
                }
            }
        }

        Benchmark(
            "KeyedNode.patch.remove10Percent",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedList(initialRows: plusDeltaRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.removeLast(deltaCount)
                    dom.drain()
                    benchmark.stopMeasurement()

                    store.append(addRows)
                    dom.drain()
                }
            }
        }

        Benchmark(
            "KeyedNode.patch.removeOne",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedList(initialRows: baseRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.removeMiddle()
                    dom.drain()
                    benchmark.stopMeasurement()

                    store.setRows(baseRows)
                    dom.drain()
                }
            }
        }

        Benchmark(
            "KeyedNode.patch.swapTwo",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedList(initialRows: baseRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.swapRows()
                    dom.drain()
                    benchmark.stopMeasurement()

                    store.swapRows()
                    dom.drain()
                }
            }
        }

        Benchmark(
            "ForEach.runFunction.stableKeys.sameValues",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedLiteList(initialRows: baseRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.setRows(baseRowsCopy)
                    dom.drain()
                    benchmark.stopMeasurement()
                }
            }
        }

        Benchmark(
            "ForEach.runFunction.stableKeys.relabel",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedLiteList(initialRows: baseRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.setRows(relabeledRows)
                    dom.drain()
                    benchmark.stopMeasurement()

                    store.setRows(baseRows)
                    dom.drain()
                }
            }
        }

        Benchmark(
            "ForEach.runFunction.changedKeys.reversed",
            configuration: .init(tags: ["rows": "\(rowCount)"])
        ) { benchmark in
            withMountedLiteList(initialRows: baseRows) { store, dom in
                for _ in benchmark.scaledIterations {
                    benchmark.startMeasurement()
                    store.setRows(reversedRows)
                    dom.drain()
                    benchmark.stopMeasurement()

                    store.setRows(baseRows)
                    dom.drain()
                }
            }
        }
    }
}
