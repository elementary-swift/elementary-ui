extension Scheduler {
    final class ScratchStorage {
        // shared scratch storage for various operations
        private var mountScratch = MountScratch()
        private var layoutEntryStorage = ScratchStackSource<LayoutPass.Entry>(initialCapacity: 16)
        private var diffEngine: KeyedDiffEngine = .init()

        func withMountScratch<R: ~Copyable>(_ body: (inout MountScratch) -> R) -> R {
            body(&mountScratch)
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
