# ``ElementaryWebComponents``

Register ElementaryUI views as autonomous browser custom elements.

## Defining an element

Use `@CustomElement` to define a custom element and `CustomElements.define` to register its
HTML tag name. The macro includes the behavior of `@View` and observes properties marked with
`@Attribute`:

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
            output { "\(value)" }
            button { label ?? "Increment" }
                .onClick { value += step }
        }
    }
}

try CustomElements.define("example-stepper", StepperElement.self, shadow: .open)
```

The same Swift type can be registered under multiple tag names. Each host element gets its own
`StepperElement` instance.

## Typed attributes

Attribute names are derived by converting Swift names to lowercase kebab case. For example,
`stepSize` becomes `step-size` and `URLValue` becomes `url-value`. Pass a string to
`@Attribute` to override the name. The macro requires explicit names to be lowercase string
literals, matching the attribute names observed by the browser. Explicit names are used as
written, without conversion to kebab case.

Built-in attribute types include strings, booleans, integers, and floating-point numbers.
Boolean values must be exactly `true` or `false`. String-backed `RawRepresentable` types can adopt
``ExpressibleByAttributeValue`` without implementing additional decoding code:

```swift
enum Theme: String, ExpressibleByAttributeValue {
    case system
    case light
    case dark
}
```

Non-optional attributes require a default value. Optional attributes default to `nil` if no
initializer is provided. Removing an HTML attribute restores the default value. Invalid values
leave the current value unchanged and log a warning.

Changes to the host's HTML attributes update the view. Assigning to an `@Attribute` property
also updates the view, but does not change the HTML attribute.

## Shadow DOM and slots

Pass `shadow: .open` to mount into an open shadow root:

```swift
try CustomElements.define("shadow-card", Card.self, shadow: .open)
```

Use `slot` in the view body to display the host's light-DOM children inside the shadow root. Shadow styles can use
standard selectors such as `:host` and `::slotted(...)`.

Use `CustomElementStyleSheet` to share styles across shadow roots:

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

Each `CustomElementStyleSheet` creates a browser stylesheet that is shared by the shadow roots
using it. The supplied array replaces the root's `adoptedStyleSheets` in the specified order;
`.open` uses an empty array. This requires browser support for constructable stylesheets and
`adoptedStyleSheets`. Creating a stylesheet can throw a `JSException`.

For a named slot, match the slot's name to the child element's `slot` attribute:

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

Existing children are preserved, and the view's nodes are appended after them. Unmounting removes
only the nodes created by ElementaryUI.

## Lifecycle and development

The view mounts when its host connects to the document and unmounts immediately when the host
disconnects. State-preserving moves with `Element.moveBefore()` retain the view and its state.
Removing and reinserting the host with other APIs recreates the view and resets its state.

Vite hot module replacement (HMR) remounts connected instances, including those inside shadow
roots, with the updated implementation and stylesheets. This resets view state. Changing the
observed attribute names reloads the page automatically. Changes to Shadow DOM mode require a
manual page reload.
