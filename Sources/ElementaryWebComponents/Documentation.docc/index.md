# ``ElementaryWebComponents``

Register ElementaryUI views as autonomous browser custom elements.

## Defining an element

`@CustomElement` includes the behavior of ElementaryUI's `@View` macro and generates the
runtime attribute table used by the browser:

```swift
import ElementaryUI
import ElementaryWebComponents

@CustomElement
struct StepperElement {
    @Attribute var value = 0
    @Attribute("step-size") var step = 1
    @Attribute var label: String?

    var body: some View {
        div {
            slot()
            button { label ?? "Increment" }
                .onClick { value += step }
        }
    }
}

try CustomElements.define("example-stepper", StepperElement.self)
```

The element name is selected at registration time, so the same Swift type can be registered
under more than one name. Each host element is a fresh `StepperElement()`. Outside registration,
that value remains an ordinary view that can be rendered inline.

## Typed attributes

Attribute names are derived by converting Swift names to lowercase kebab case. For example,
`stepSize` becomes `step-size` and `URLValue` becomes `url-value`. Pass a string to
`@Attribute` to override the name.

Present values are decoded as strings, case-sensitive textual booleans (`true` or `false`), integers, or
floating-point values. String-backed `RawRepresentable` types can adopt
``CustomElementAttributeValue`` without implementing additional decoding code:

```swift
enum Theme: String, CustomElementAttributeValue {
    case system
    case light
    case dark
}
```

Non-optional attributes require a declaration-time default. An optional attribute may omit its
initializer and defaults to `nil`. Removing an attribute restores its declaration-time default;
invalid text preserves the current value and emits an Elementary warning.

Attribute updates flow from the host into Swift. Assigning to an `@Attribute` property updates
the view reactively but does not reflect the new value back to HTML.

## Shadow DOM and slots

Pass `shadow: .open` to mount into an open shadow root:

```swift
try CustomElements.define("shadow-card", Card.self, shadow: .open)
```

Render a native `slot` in the Swift body to project light-DOM children. Shadow styles can use
standard selectors such as `:host` and `::slotted(...)`.

Use constructable stylesheets for styles shared by multiple element registrations:

```swift
let cardStyles = try CustomElementStyleSheet("""
    :host {
        display: block;
    }
    """)

try CustomElements.define(
    "shadow-card",
    Card.self,
    shadow: .open(styleSheets: [cardStyles])
)
```

The stylesheet is created once with `CSSStyleSheet.replaceSync` and the same browser object is
adopted by every shadow root. The array order is preserved, and each component owns the complete
`adoptedStyleSheets` list for its root. Passing `.open` adopts an empty list. Browsers must support
constructable stylesheets and `adoptedStyleSheets`; stylesheet construction surfaces native
`JSException` errors.

Named slots use the native HTML names on both sides:

```swift
slot(.name("actions"))
```

```html
<example-stepper>
  <button slot="actions">Reset</button>
</example-stepper>
```

Omitting `shadow` mounts directly into the host:

```swift
try CustomElements.define("light-card", Card.self)
```

Light-DOM mounting follows ElementaryUI's normal container behavior: existing authored children
are preserved and ElementaryUI-owned nodes are appended after them. Unmounting removes only the
ElementaryUI-owned nodes.

## Lifecycle and development

The view mounts when its host connects and is destroyed immediately when the host disconnects.
Moving a host with `Element.moveBefore()` retains ElementaryUI state through the browser's
`connectedMoveCallback()` lifecycle. Other removal and insertion APIs create a fresh view and
state tree.

During Vite HMR, registrations with unchanged attribute names and Shadow DOM mode replace their
implementation and reconstruct live instances. Stylesheet changes are applied during
reconstruction without a reload. Changing the attribute names or Shadow DOM mode forces a full
reload. HMR reconstruction resets view state.

The initial release intentionally leaves closed shadow roots, custom-event helpers, form
association, focus delegation, manual slot assignment, scoped registries, JavaScript property
inputs, declarative-shadow hydration, and attribute reflection for future APIs.
