extension Scheduler {
    final class ScratchStorage {
        // shared scratch storage for various operations
        private var layoutNodeStorage = ScratchStackSource<LayoutNode>(initialCapacity: 16)
        private var layoutEntryStorage = ScratchStackSource<LayoutPass.Entry>(initialCapacity: 16)
        private var diffEngine: KeyedDiffEngine = .init()

        func withLayoutNodeScratchFrame<R: ~Copyable>(
            _ body: (consuming ScratchStack<LayoutNode>) -> R
        ) -> R {
            layoutNodeStorage.withStack(body)
        }

        func withLayoutEntryScratchFrame<R: ~Copyable>(
            _ body: (consuming ScratchStack<LayoutPass.Entry>) -> R
        ) -> R {
            layoutEntryStorage.withStack(body)
        }

        func withDiffEngine<R: ~Copyable>(_ body: (inout KeyedDiffEngine) -> R) -> R {
            body(&diffEngine)
        }
    }
}
