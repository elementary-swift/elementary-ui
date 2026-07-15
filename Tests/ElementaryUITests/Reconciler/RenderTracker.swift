import ElementaryUI
import Reactivity

final class RenderTracker {
    private(set) var calls: [String] = []

    init() {
        print("RenderTracker init")
    }

    func record(_ name: String) {
        calls.append(name)
    }

    func reset() {
        calls.removeAll()
    }
}

extension EnvironmentValues {
    @Entry var tracker: RenderTracker
}

@View
struct Track<Wrapped: View> {
    @Environment(#Key(\.tracker)) var tracker
    var name: String
    @ContentBuilder let wrapped: Wrapped

    var body: some View {
        let _ = tracker.record(name)
        wrapped
    }
}
