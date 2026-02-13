public extension View {
    /// Binds this view's focus to a boolean ``FocusState``.
    ///
    /// Use this when a focus state binding tracks a single view.
    /// The binding stays in sync in both directions:
    ///
    /// - Moving focus to this element sets the binding to `true`.
    /// - Setting the binding to `true` programmatically moves focus to this element.
    /// - Moving focus away from this element sets the binding to `false`.
    /// - Setting the binding to `false` clears focus.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @View
    /// struct UsernameForm {
    ///     @State var username: String = ""
    ///     @FocusState var usernameFieldIsFocused: Bool
    ///     @State var showUsernameTaken = false
    ///
    ///     var body: some View {
    ///         input(.type(.text), .placeholder("Choose a username."))
    ///             .bindValue($username)
    ///             .focused($usernameFieldIsFocused)
    ///
    ///         if showUsernameTaken {
    ///             p { "That username is taken. Please choose another." }
    ///         }
    ///
    ///         button { "Submit" }
    ///             .onClick {
    ///                 showUsernameTaken = false
    ///                 if !isUserNameAvailable(username: username) {
    ///                     usernameFieldIsFocused = true
    ///                     showUsernameTaken = true
    ///                 }
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter binding: A boolean focus binding, typically from `@FocusState`.
    /// - Returns: A view that reads and updates focus through the binding.
    consuming func focused(_ binding: FocusState<Bool>.Binding) -> some View<Tag> {
        DOMEffectView<FocusModifier<Bool>, Self>(value: .init(storage: binding.storage), wrapped: self)
    }

    /// Binds this view's focus to a keyed ``FocusState`` binding.
    ///
    /// Use this when a focus state binding tracks multiple views.
    /// The binding stays in sync in both directions:
    ///
    /// - Moving focus to this element sets the binding to `value`.
    /// - Setting the binding to `value` programmatically moves focus to this element.
    /// - Moving focus away from this element sets the binding to `nil`.
    /// - Setting the binding to `nil` clears focus.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @View
    /// struct LoginForm {
    ///     enum Field: Hashable {
    ///         case usernameField
    ///         case passwordField
    ///     }
    ///
    ///     @State private var username = ""
    ///     @State private var password = ""
    ///     @FocusState private var focusedField: Field?
    ///
    ///     var body: some View {
    ///         input(.type(.text), .placeholder("Username"))
    ///             .bindValue($username)
    ///             .focused($focusedField, equals: .usernameField)
    ///
    ///         input(.type(.password), .placeholder("Password"))
    ///             .bindValue($password)
    ///             .focused($focusedField, equals: .passwordField)
    ///
    ///         button { "Sign In" }
    ///             .onClick {
    ///                 if username.isEmpty {
    ///                     focusedField = .usernameField
    ///                 } else if password.isEmpty {
    ///                     focusedField = .passwordField
    ///                 } else {
    ///                     handleLogin(username, password)
    ///                 }
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - binding: A keyed optional focus binding, typically from `@FocusState`.
    ///   - value: The key that represents this element in the bound focus state.
    /// - Returns: A view that participates in keyed focus selection.
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
