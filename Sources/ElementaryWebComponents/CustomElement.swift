import ElementaryUI

/// A view that can be registered as an autonomous browser custom element.
public protocol CustomElement: View {
    /// Creates the view for a host element.
    init()

    static var __observedAttributes: [String] { get }
    func __applyCustomElementContext(_ hostContext: inout _CustomElementHostContext)
}

/// Defines a browser custom element using an ElementaryUI view.
///
/// Choose the HTML tag name and Shadow DOM options when registering the type with ``CustomElements/define(_:_:shadow:)``.
@attached(
    member,
    names: named(__observedAttributes)
)
@attached(
    extension,
    conformances: __FunctionView,
    View,
    __ViewEquatable,
    CustomElement,
    names: named(__applyCustomElementContext),
    named(__initializeState),
    named(__restoreState),
    named(__applyContext),
    named(__ViewState),
    named(_MountedNode),
    named(__arePropertiesEqual)
)
@attached(memberAttribute)
public macro CustomElement() = #externalMacro(module: "ElementaryUIMacros", type: "CustomElementMacro")
