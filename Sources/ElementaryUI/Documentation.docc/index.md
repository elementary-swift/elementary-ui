# ``ElementaryUI``

A SwiftUI-inspired frontend framework

ElementaryUI brings declarative Swift applications to the browser with WebAssembly. With familiar APIs, built-in reactivity, and a magical animation system, you can create beautiful web apps with a few lines of Swift code. The framework is fully compatible with [Embedded Swift](https://docs.swift.org/embedded/documentation/embedded/), so your wasm binaries are measured in kB instead of MB.

```swift
@View
struct Counter {
    @State var count = 0
    
    var body: some View {
        div {
            p { "Count: \(count)" }
            button { "Increment" }
                .onClick { count += 1 }
        }
    }
}
```

## Get Started

Visit the guide at [**elementary.codes**](https://elementary.codes).

## Mounting an application
- ``Application``

## Defining views

- ``View()-macro``
- ``State``
- ``Environment``

## Lifecycle
- ``View/onAppear(_:)``
- ``View/onDisappear(_:)``
- ``View/onChange(of:initial:_:)``

## Animations
- ``withAnimation(_:_:)``
- ``View/animation(_:value:)``
- ``Animatable``