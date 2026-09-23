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
    shadowDOM: .open(styleSheets: [sharedStyleSheet])
) {
    BrowserCounter()
}

var duplicateRegistrationFailed = false
do {
    try CustomElements.define(
        "test-counter",
        shadowDOM: .open(styleSheets: [sharedStyleSheet, hotReloadStyleSheet])
    ) {
        BrowserCounter()
    }
} catch {
    duplicateRegistrationFailed = true
}

var invalidRegistrationFailed = false
do {
    try CustomElements.define("invalid") {
        BrowserCounter()
    }
} catch {
    invalidRegistrationFailed = true
}

try! CustomElements.define("test-light-counter", shadowDOM: .none) {
    BrowserCounter()
}

try! CustomElements.define(
    "test-styled-counter",
    shadowDOM: .open(styleSheets: [sharedStyleSheet, orderedStyleSheet])
) {
    BrowserCounter()
}

try! CustomElements.define(
    "test-shared-counter",
    shadowDOM: .open(styleSheets: [sharedStyleSheet])
) {
    BrowserCounter()
}

try! CustomElements.define("test-unstyled-counter") {
    BrowserCounter()
}

JSObject.global["__elementaryDuplicateRegistrationFailed"] = .boolean(duplicateRegistrationFailed)
JSObject.global["__elementaryInvalidRegistrationFailed"] = .boolean(invalidRegistrationFailed)
