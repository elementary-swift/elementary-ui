import ElementaryUI

/// A view that can be registered as an autonomous browser custom element.
public protocol CustomElement: View {
    /// Creates the view mounted for one host element.
    init()

    /// Attribute names observed by the browser custom-element implementation.
    ///
    /// This is a static list so registration does not need to build a view.
    static var observedAttributes: [String] { get }

    /// Collects the `@Attribute` slots this value already holds.
    static func __attributes(from view: borrowing Self) -> _CustomElementAttributeStorage
}

/// Marks a struct as both an ElementaryUI view and a browser custom-element definition.
///
/// The element's tag name and Shadow DOM policy are intentionally selected when the type is
/// registered with ``CustomElements/define(_:_:shadow:)``.
@attached(
    member,
    names: named(observedAttributes),
    named(__attributes)
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
