public struct _CommitContext: ~Copyable {
    let dom: DOMInteractor
    let scheduler: Scheduler
    let currentFrameTime: Double

    init(dom: DOMInteractor, scheduler: Scheduler, currentFrameTime: Double) {
        self.dom = dom
        self.currentFrameTime = currentFrameTime
        self.scheduler = scheduler
    }
}
