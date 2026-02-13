final class FocusModifier<FocusValue: Hashable>: DOMElementModifier, Unmountable {
    private var binding: Binding
    private var focusAccessor: DOM.FocusAccessor?

    init(value: consuming Binding, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.binding = value
    }

    func updateValue(_ value: consuming Binding, _ context: inout _TransactionContext) {
        guard value.storage === self.binding.storage else {
            logWarning("Updating FocusState.Binding is not supported")
            return
        }

        self.binding = value
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        if focusAccessor != nil {
            assertionFailure("FocusModifier can only be mounted on a single element")
            logWarning("FocusModifier can only be mounted on a single element")
            self.unmount(&context)
        }

        binding.register(focusable: self)
        self.focusAccessor = context.dom.makeFocusAccessor(node) { [binding] event in
            switch event {
            case .focus:
                binding.reportFocus()
            case .blur:
                binding.reportBlur()
            }
        }

        return AnyUnmountable(self)
    }

    func unmount(_ context: inout _CommitContext) {
        guard focusAccessor != nil else { return }
        binding.unregister(focusable: self)
        self.focusAccessor.take()?.unmount()
    }
}

extension FocusModifier {
    struct Binding {
        let storage: FocusStateStorage<FocusValue>
        let value: FocusValue

        init(storage: FocusStateStorage<FocusValue>, value: FocusValue) {
            self.storage = storage
            self.value = value
        }

        init(storage: FocusStateStorage<FocusValue>) where FocusValue == Bool {
            self.storage = storage
            self.value = true
        }

        func register(focusable: any Focusable) {
            storage.register(focusable, for: value)
        }

        func unregister(focusable: any Focusable) {
            storage.unregister(focusable, for: value)
        }

        func reportFocus() {
            storage.reportFocus(value: value)
        }

        func reportBlur() {
            storage.reportBlur(value: value)
        }
    }
}

extension FocusModifier: Focusable {
    func focus() {
        focusAccessor?.focus()
    }

    func blur() {
        focusAccessor?.blur()
    }
}
