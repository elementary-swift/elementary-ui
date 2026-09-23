import ElementaryUI

/// A view that can be registered as an autonomous browser custom element.
public protocol CustomElement: View {
    /// Attribute names observed by the browser custom-element implementation.
    static var observedAttributes: [String] { get }

    /// Updates an observed attribute by its HTML name.
    ///
    /// - Returns: `false` when `name` is unknown or `value` cannot be decoded.
    func setAttribute(name: String, value: String?) -> Bool
}

/// Marks a struct as both an ElementaryUI view and a browser custom-element definition.
///
/// The element's tag name and Shadow DOM policy are intentionally selected when the type is
/// registered with ``CustomElements/define(_:shadowDOM:factory:)``.
@attached(
    member,
    names: named(observedAttributes),
    named(setAttribute)
)
@attached(
    extension,
    conformances: __FunctionView,
    View,
    __ViewEquatable,
    CustomElement,
    names: named(__initializeState),
    named(__restoreState),
    named(__applyContext),
    named(__ViewState),
    named(_MountedNode),
    named(__arePropertiesEqual)
)
@attached(memberAttribute)
public macro CustomElement() = #externalMacro(module: "ElementaryUIMacros", type: "CustomElementMacro")
