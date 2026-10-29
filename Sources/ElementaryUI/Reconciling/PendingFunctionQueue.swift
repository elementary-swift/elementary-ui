import BasicContainers

struct PendingFunctionQueue: ~Copyable {
    private struct Entry {
        let function: SchedulableNode
        let transaction: Transaction?
    }

    // Sorted by depth in descending order, so the shallowest function is always popped first.
    private var functionsToRun = UniqueArray<Entry>()

    var isEmpty: Bool { functionsToRun.isEmpty }

    mutating func registerFunctionForUpdate(_ function: SchedulableNode, transaction: Transaction?) {
        logTrace("registering function run \(ObjectIdentifier(function))")
        // Insertion from the back: functions mostly arrive at equal or decreasing depth.
        functionsToRun.append(Entry(function: function, transaction: transaction))
        var index = functionsToRun.count - 1
        while index > 0, functionsToRun[index - 1].function.depthInTree < function.depthInTree {
            functionsToRun.swapAt(index, index - 1)
            index -= 1
        }
    }

    mutating func next() -> (SchedulableNode, Transaction?)? {
        guard let entry = functionsToRun.popLast() else { return nil }
        return (entry.function, entry.transaction)
    }

    deinit {
        assert(functionsToRun.isEmpty, "pending functions dropped without being run")
    }
}
