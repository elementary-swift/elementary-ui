public extension View where Tag == HTMLTag.input {
    /// Binds an input's value to a string binding.
    ///
    /// Use this method to create a two-way binding between an input element
    /// and a string value. Changes to the binding update the input, and user
    /// input updates the binding.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @View
    /// struct TextInput {
    ///     @State var text: String = ""
    ///
    ///     var body: some View {
    ///         input(.type(.text))
    ///             .bindValue($text)
    ///         p { "You typed: \(text)" }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter value: A binding to a string value.
    /// - Returns: An input view bound to the string value.
    consuming func bindValue(_ value: Binding<String>) -> some View<Tag> {
        DOMEffectView<BindingModifier<TextBindingConfiguration>, Self>(value: value, wrapped: self)
    }

    /// Binds a number input's value to an optional double binding.
    ///
    /// Use this method to create a two-way binding between a number input
    /// and an optional double value. Invalid input results in `nil`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @View
    /// struct NumberInput {
    ///     @State var amount: Double? = 0
    ///
    ///     var body: some View {
    ///         input(.type(.number))
    ///             .bindValue($amount)
    ///         if let amount {
    ///             p { "Amount: \(amount)" }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter value: A binding to an optional double value.
    /// - Returns: An input view bound to the number value.
    consuming func bindValue(_ value: Binding<Double?>) -> some View<Tag> {
        DOMEffectView<BindingModifier<NumberBindingConfiguration>, Self>(value: value, wrapped: self)
    }

    /// Binds a checkbox input's checked state to a boolean binding.
    ///
    /// Use this method to create a two-way binding between a checkbox input
    /// and a boolean value.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @View
    /// struct Checkbox {
    ///     @State var isChecked: Bool = false
    ///
    ///     var body: some View {
    ///         input(.type(.checkbox))
    ///             .bindChecked($isChecked)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter value: A binding to a boolean value.
    /// - Returns: An input view bound to the checkbox state.
    consuming func bindChecked(_ value: Binding<Bool>) -> some View<Tag> {
        DOMEffectView<BindingModifier<CheckboxBindingConfiguration>, Self>(value: value, wrapped: self)
    }
}

struct DOMEffectView<Effect: DOMElementModifier, Wrapped: View>: View {
    typealias Body = Never
    typealias Tag = Wrapped.Tag
    var value: Effect.Value
    var wrapped: Wrapped

    typealias _MountedNode = _StatefulNode<Effect, Wrapped._MountedNode>

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        tx: inout _TransactionContext
    ) -> _MountedNode {
        let effect = Effect(value: view.value, upstream: context.modifiers, &tx)

        #if hasFeature(Embedded) && compiler(<6.3)
        if __omg_this_was_annoying_I_am_false {
            var context = _CommitContext(
                dom: JSKitDOMInteractor(),
                scheduler: Scheduler(dom: JSKitDOMInteractor()),
                currentFrameTime: 0
            )
            // force inclusion of types used in mount
            _ = effect.mount(.init(.init()), &context)
        }
        #endif

        var context = copy context
        context.modifiers[Effect.key] = effect

        return .init(state: effect, child: Wrapped._makeNode(view.wrapped, context: context, tx: &tx))
    }

    static func _patchNode(
        _ view: consuming Self,
        node: _MountedNode,
        tx: inout _TransactionContext
    ) {
        node.state.updateValue(view.value, &tx)
        Wrapped._patchNode(view.wrapped, node: node.child, tx: &tx)
    }
}
