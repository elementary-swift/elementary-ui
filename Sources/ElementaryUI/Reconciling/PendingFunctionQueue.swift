import BasicContainers

struct PendingFunctionQueue: ~Copyable {
    private var functionsToRun: UniqueArray<(_SchedulableNode, Transaction?)> = .init()

    var isEmpty: Bool { functionsToRun.isEmpty }

    // TODO: add transaction here?
    mutating func registerFunctionForUpdate(_ node: _SchedulableNode, transaction: Transaction?) {
        logTrace("registering function run \(node.identifier)")
        // sorted insert by depth in reverse order, avoiding duplicates
        var inserted = false

        for index in functionsToRun.indices {
            let (existingNode, transaction) = functionsToRun[index]
            if existingNode.identifier == node.identifier {
                // update transaction to the one provided deepest in the tree
                functionsToRun[index].1 = transaction
                inserted = true
                break
            }
            if node.depthInTree > existingNode.depthInTree {
                functionsToRun.insert((node, transaction), at: index)
                inserted = true
                break
            }
        }
        if !inserted {
            functionsToRun.append((node, transaction))
        }
    }

    mutating func next() -> (_SchedulableNode, Transaction?)? {
        functionsToRun.popLast()
    }

    deinit {
        assert(functionsToRun.isEmpty, "pending functions dropped without being run")
    }
}
