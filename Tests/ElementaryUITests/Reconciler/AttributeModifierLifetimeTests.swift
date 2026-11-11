import Elementary
import Reactivity
import Testing

@testable import ElementaryUI

struct AttributeModifierLifetimeTests {
    @Test
    func downstreamModifiersLeaveTheirUpstream() {
        let model = LifetimeModel()
        let probe = ModifierProbe.Captured()
        let dom = TestDOM()
        let app = dom.mount {
            _AttributedContent(
                content: Rows(model: model, probe: probe),
                attributes: _AttributeStorage(MarkupAttribute<HTMLTag.div>.class("outer"))
            )
        }
        dom.runNextFrame()

        weak var weakWrapper: AttributeModifier?
        do {
            let wrapper = probe.modifier!
            weakWrapper = wrapper
            let hasDependentsWhileShown = !wrapper.dependents.isEmpty
            #expect(hasDependentsWhileShown)

            model.isShown = false
            dom.runNextFrame()
            let isEmptyAfterRemoval = wrapper.dependents.isEmpty
            #expect(isEmptyAfterRemoval)
        }

        probe.modifier = nil
        app.unmount()
        dom.runNextFrame()
        #expect(weakWrapper == nil)
    }
}

@Reactive
private final class LifetimeModel {
    var isShown = true
}

@View
private struct Rows {
    let model: LifetimeModel
    let probe: ModifierProbe.Captured

    var body: some View {
        ModifierProbe(captured: probe)
        if model.isShown {
            p { "row" }
        }
    }
}

/// Captures the attribute modifier its context passes down.
private struct ModifierProbe: View {
    final class Captured {
        var modifier: AttributeModifier?
    }

    let captured: Captured

    static func _makeNode(
        _ view: consuming ModifierProbe,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _MountedNode {
        view.captured.modifier = context.modifiers[AttributeModifier.key]
        return _MountedNode()
    }

    static func _patchNode(
        _ view: consuming ModifierProbe,
        node: inout _MountedNode,
        tx: inout _TransactionContext
    ) {}

    final class _MountedNode {}

    var body: Never {
        fatalError()
    }
}
