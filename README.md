<p align="center">
  <a href="https://elementary.codes">
    <img src="https://elementary-swift.github.io/assets/elementary-logo.svg" width="125px" alt="Elementary Logo">
  </a>
</p>

# ElementaryUI - A Swift Frontend Framework

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Felementary-swift%2Felementary-ui%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/elementary-swift/elementary-ui)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Felementary-swift%2Felementary-ui%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/elementary-swift/elementary-ui)

## Features

- 🌐 **Swift in the Browser** - Run declarative Swift applications natively in the browser with WebAssembly
- 🎨 **SwiftUI-inspired APIs** - Familiar and intuitive syntax for building web UIs
- ⚡ **Built-in Reactivity** - Automatic state management with `@State`, `@Environment`, and `@Reactive`
- 📦 **Tiny Binaries** - Full Embedded Swift support means kB-sized wasm bundles instead of MB
- ✨ **Magical Animations** - Powerful CSS-based animation system including automatic FLIP transitions
- 🚀 **Vite-Powered Development** - Fast dev server with hot reload for rapid iteration

<br>

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

> [!NOTE]
> ElementaryUI is an actively developed passion project in its early days.
> Expect sharp edges, APIs may change, and things may break as I balance performance, ergonomics, and feature set.
>
> The ambition is simple: make Swift a first-class option for building serious web applications, and keep the project healthy for the long run.
> 
> If you want this to exist and keep improving, sponsorship funds the work.  
> [![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/sliemeobn)

## Get Started

Go from zero to Swift-in-the-browser in minutes, with the **[Vite Starter](https://github.com/elementary-swift/starter-vite)** template.

## Guides & Documentation

- **Guide**: [elementary.codes](https://elementary.codes)
- **API docs**: [Swift Package Index](https://swiftpackageindex.com/elementary-swift/elementary-ui/documentation)

## Example

[Check out the "Swiftle" demo app](/Examples/Swiftle/)

## 🚧 Work In Progress 🚧
Based on the [swift.org WebAssembly SDKs](https://forums.swift.org/t/swift-sdks-for-webassembly-now-available-on-swift-org/80405), [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit), and [Elementary](https://github.com/elementary-swift/elementary).

Swift 6.2 or later with matching *Swift SDKs for WebAssembly* from [swift.org](https://www.swift.org/install) is required.

### Things to figure out

- ~~identity system and list-diffing~~
- ~~lifecycle events and proper "unmounting" (currently nodes are just "dropped")~~
- ~~@State system~~
- ~~typed event handlers~~
- ~~@Environment system~~
- ~~dependencies on versioned packages (i.e., build without unsafe flags)~~
- ~~fix DOM not child-diffing to preserve animations/nodes (the current solution based on `replaceChildren` will not work, it seems)~~
- ~~"model-bindings" for inputs (i.e., bind a @Binding<String> to a text box, or bind a @Binding<Bool> to a checkbox)~~
- ~~view value comparing (generated comparing and custom equatable support)~~
- ~~different handling of environment (individual reactivity needed)~~
- ~~transitions and animations (ideally CSS-based, probably svelte-like custom easing functions applied through WAAPI)~~
- ~~better control over animations~~
- ~~somehow migrate over to "var body" instead of "var content" (what was I thinking....)~~
- ~~automatic FLIP animations for certain layout changes (child-layout after changes, maybe size of containers)~~
- ~~fix those Foundation imports, review thread-local + mutex usage~~
- more built-in animatable CSS modifiers (colors, borders, blur)
- basic phaseAnimator implementations
- implement auto-flip animation for custom CSS values (on value triggers)
- maybe add "animateContainerLayout" modifier with value trigger (eg: to animate changes without child-changes)
- support for combined and reversible transitions
- multi-select bindings (options, radio-buttons, tagged check boxes, ...)
- more unit testing (FLIP handling, animations, reactivity, ...)
- implement @ViewEquatableIgnored
- split out JavaScriptKit stuff in separate module to contain spread, maybe one day we can switch to faster interop somehow
- ~~add basic docs, a good intro readme, and push a 0.1 out the door! (probably best to wait for Swift 6.2 to drop)~~
- a router implementation (probably in extra module?)
- maybe conditionally support @Observable for non-embedded builds?
- ~~figure out why `@Environment` with optional `ReactiveObject` does not build in embedded~~
- preference system (i.e., bubbling up values)
- embedded-friendly Browser APIs (Storage, History, maybe in swiftwasm package with new JavaScriptKit macros)
- ~~think about how to deal with the lack of `Codable` in embedded (wait for new serialization macros)~~
- ~~make printing work without WASI (maybe pipe putchar through to JavaScript?)~~
- isolation and @MainActor stuff for reusable types (server-side rendering and client apps - probably never quite possible to have same types render "multi-threaded" server side and stay single-threaded client side....)
- ~~decide whether the current idea of `Views` flattening themselves into renderable types is even necessary, or if views should just "apply" themselves into the reconciler - might be a bit messier, but maybe faster and more flexible~~
- ~~move all elementary repos under one project roof and use a traits-based, single "ElementaryUI" top-level package (or similar)~~

### Embedded Swift for WASM waitlist

- Codable 2.0 (we need JSON handling for embedded, on [the horizon](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585))
- ~~simple build with SwiftPM (wasm-ld)~~
- ~~\_Concurrency module (Task)~~
- ~~Synchronization (Mutex)~~

## License and Derived Code

This package is generally licensed as [Apache 2](LICENSE).

The `Reactivity` module is inspired by the Swift stdlib's `Observation` framework, and code in `ReactivityMacros` is directly derived from it ([source](https://github.com/swiftlang/swift/tree/main/lib/Macros/Sources/ObservationMacros)).
Find a copy of the Swift.org open source project license [here](LICENSE-swift_org.md).

This repo also contains the [BrowserRuntime](BrowserRuntime) JavaScript package which bundles source code from [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) (see [license](./BrowserRuntime/LICENSE.md))

---

*SwiftUI is a trademark of Apple Inc. This project is not affiliated with or connected to Apple in any way.*
