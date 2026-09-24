import ElementaryUI
import ElementaryWebComponents
import JavaScriptKit

@CustomElement
struct BrowserCounter {
    @Attribute var count = 1
    @Attribute var label: String?
    @State var localCount = 0

    var body: some View {
        style {
            """
            :host { display: block; }
            """
        }
        slot()
        slot(.name("note"))
        output(.id("value")) {
            "\(count):\(localCount):\(label ?? "nil")"
        }
        button(.id("increment")) { "Increment" }
            .onClick { localCount += 1 }
    }
}

let sharedStyleSheet = try! CustomElementStyleSheet(
    """
    :host { color: rgb(10, 20, 30); }
    """
)
let orderedStyleSheet = try! CustomElementStyleSheet(
    """
    :host { color: rgb(40, 50, 60); }
    """
)
let hotReloadStyleSheet = try! CustomElementStyleSheet(
    """
    :host { color: rgb(70, 80, 90); }
    """
)

try! CustomElements.define(
    "test-counter",
    BrowserCounter.self,
    shadow: .open(styleSheets: [sharedStyleSheet])
)

let replaceCounter = JSClosure { _ in
    do {
        try CustomElements.define(
            "test-counter",
            BrowserCounter.self,
            shadow: .open(styleSheets: [sharedStyleSheet, hotReloadStyleSheet])
        )
        return .boolean(true)
    } catch {
        return .boolean(false)
    }
}
JSObject.global["__elementaryReplaceCounter"] = .object(replaceCounter)

var invalidRegistrationFailed = false
do {
    try CustomElements.define("invalid", BrowserCounter.self)
} catch {
    invalidRegistrationFailed = true
}

try! CustomElements.define("test-light-counter", BrowserCounter.self)

try! CustomElements.define(
    "test-styled-counter",
    BrowserCounter.self,
    shadow: .open(styleSheets: [sharedStyleSheet, orderedStyleSheet])
)

try! CustomElements.define(
    "test-shared-counter",
    BrowserCounter.self,
    shadow: .open(styleSheets: [sharedStyleSheet])
)

try! CustomElements.define("test-unstyled-counter", BrowserCounter.self, shadow: .open)

JSObject.global["__elementaryInvalidRegistrationFailed"] = .boolean(invalidRegistrationFailed)
