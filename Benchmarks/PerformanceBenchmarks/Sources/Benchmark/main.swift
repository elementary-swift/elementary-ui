import ElementaryUI
import Reactivity

// MARK: - Data

struct Row: Equatable {
    let id: Int
    var label: String

    static func == (lhs: Row, rhs: Row) -> Bool {
        lhs.id == rhs.id && lhs.label.utf8.elementsEqual(rhs.label.utf8)
    }
}

private let adjectives = [
    "pretty", "large", "big", "small", "tall", "short", "long", "handsome",
    "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful",
    "mushy", "odd", "unsightly", "adorable", "important", "inexpensive",
    "cheap", "expensive", "fancy",
]

private let colours = [
    "red", "yellow", "blue", "green", "pink", "brown", "purple", "brown",
    "white", "black", "orange",
]

private let nouns = [
    "table", "chair", "house", "bbq", "desk", "car", "pony", "cookie",
    "sandwich", "burger", "pizza", "mouse", "keyboard",
]

private func randomLabel() -> String {
    "\(adjectives[.random(in: 0..<adjectives.count)]) \(colours[.random(in: 0..<colours.count)]) \(nouns[.random(in: 0..<nouns.count)])"
}

// MARK: - Store

@Reactive
final class BenchmarkStore {
    var rows: [Row] = []
    var selectedID: Int = -1
    private var nextID: Int = 1

    func run() {
        rows = buildData(1000)
        selectedID = -1
    }

    func runLots() {
        rows = buildData(10000)
        selectedID = -1
    }

    func add() {
        rows.append(contentsOf: buildData(1000))
    }

    func update() {
        var i = 0
        while i < rows.count {
            rows[i].label += " !!!"
            i += 10
        }
    }

    func clear() {
        rows = []
        selectedID = -1
    }

    func swapRows() {
        guard rows.count > 998 else { return }
        swap(&rows[1], &rows[998])
    }

    func select(_ id: Int) {
        selectedID = id
    }

    func delete(_ id: Int) {
        rows.removeAll { $0.id == id }
    }

    private func buildData(_ count: Int) -> [Row] {
        var data: [Row] = []
        let d = ContinuousClock().measure {

            data.reserveCapacity(count)
            for _ in 0..<count {
                data.append(Row(id: nextID, label: randomLabel()))
                nextID += 1
            }
        }
        print("buildData: \(d)")
        return data
    }
}

// MARK: - Sub-views

@View
struct ActionButton {
    var buttonID: String
    var label: String
    var action: () -> Void

    var body: some View {
        div(.class("col-sm-6 smallpad")) {
            button(.id(buttonID), .type(.button), .class("btn btn-primary btn-block")) {
                label
            }
            .onClick { action() }
        }
    }
}

@View
struct RowView {
    @Environment(BenchmarkStore.self) var store: BenchmarkStore
    var row: Row
    var isSelected: Bool

    var body: some View {
        tr(.class(isSelected ? "danger" : "")) {
            td(.class("col-md-1")) {
                "\(row.id)"
            }
            td(.class("col-md-4")) {
                a { row.label }
                    .onClick { store.select(row.id) }
            }
            td(.class("col-md-1")) {
                a {
                    span(.class("glyphicon glyphicon-remove")) {}
                        .attributes(.custom(name: "aria-hidden", value: "true"))
                }
                .onClick { store.delete(row.id) }
            }
            td(.class("col-md-6")) {}
        }
    }
}

@View
struct DataTable {
    @Environment(BenchmarkStore.self) var store: BenchmarkStore

    var body: some View {
        table(.class("table table-hover table-striped test-data")) {
            tbody(.id("tbody")) {
                let _ = print("DataTable: \(store.selectedID)")
                ForEach(store.rows, key: { $0.id }) { row in
                    RowView(
                        row: row,
                        isSelected: store.selectedID == row.id
                    )
                }
            }
        }
    }
}

@View
struct Jumbotron {
    @Environment(BenchmarkStore.self) var store: BenchmarkStore

    var body: some View {
        div(.class("jumbotron")) {
            div(.class("row")) {
                div(.class("col-md-6")) {
                    h1 { "ElementaryUI (keyed)" }
                }
                div(.class("col-md-6")) {
                    div(.class("row")) {
                        ActionButton(buttonID: "run", label: "Create 1,000 rows", action: store.run)
                        ActionButton(buttonID: "runlots", label: "Create 10,000 rows", action: store.runLots)
                        ActionButton(buttonID: "add", label: "Append 1,000 rows", action: store.add)
                        ActionButton(buttonID: "update", label: "Update every 10th row", action: store.update)
                        ActionButton(buttonID: "clear", label: "Clear", action: store.clear)
                        ActionButton(buttonID: "swaprows", label: "Swap Rows", action: store.swapRows)
                    }
                }
            }
        }
    }
}

// MARK: - App

@View
struct BenchmarkApp {
    @State var store = BenchmarkStore()

    var body: some View {
        div(.id("main")) {
            div(.class("container")) {
                Jumbotron()
                DataTable()
                span(.class("preloadicon glyphicon glyphicon-remove")) {}
                    .attributes(.custom(name: "aria-hidden", value: "true"))
            }
        }
        .environment(store)
    }
}

Application(BenchmarkApp()).mount(in: "#app")
