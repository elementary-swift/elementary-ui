extension Scheduler {
    /// Buffers reused across updates; see ``ScratchFrame``.
    final class ScratchStorage {
        private var mount = MountBuffers()
        private var layoutEntries = ScratchBuffer<LayoutPass.Entry>(minimumCapacity: 16)
        private var diffEngine: KeyedDiffEngine = .init()

        func withMountFrames<R: ~Copyable>(
            _ body: (consuming ScratchFrame<LayoutNode>, consuming ScratchFrame<SlotRegistration>) -> R
        ) -> R {
            mount.withFrames(body)
        }

        func withLayoutEntryFrame<R: ~Copyable>(
            _ body: (consuming ScratchFrame<LayoutPass.Entry>) -> R
        ) -> R {
            layoutEntries.withFrame(body)
        }

        func withDiffEngine<R: ~Copyable>(_ body: (inout KeyedDiffEngine) -> R) -> R {
            body(&diffEngine)
        }
    }

    private struct MountBuffers: ~Copyable {
        var layoutNodes = ScratchBuffer<LayoutNode>(minimumCapacity: 16)
        var registrations = ScratchBuffer<SlotRegistration>(minimumCapacity: 16)

        mutating func withFrames<R: ~Copyable>(
            _ body: (consuming ScratchFrame<LayoutNode>, consuming ScratchFrame<SlotRegistration>) -> R
        ) -> R {
            body(layoutNodes.frame(), registrations.frame())
        }
    }
}
