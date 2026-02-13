public extension View {
    /// Binds a view's focus state to a boolean focus binding.
    ///
    /// When the element receives focus, the binding becomes `true`.
    /// When it loses focus, the binding becomes `false`.
    consuming func focused(_ binding: FocusState<Bool>.Binding) -> some View<Tag> {
        DOMEffectView<FocusModifier<Bool>, Self>(value: .init(storage: binding.storage), wrapped: self)
    }

    /// Binds a view's focus state to an enum/ID-based focus binding.
    ///
    /// When the element receives focus, the binding becomes `equals`.
    /// When it loses focus, the binding becomes `nil` (if it still equals this value).
    consuming func focused<Key>(
        _ binding: FocusState<Key?>.Binding,
        equals value: Key
    ) -> some View<Tag> {
        DOMEffectView<FocusModifier<Key?>, Self>(
            value: .init(storage: binding.storage, value: value),
            wrapped: self
        )
    }
}
