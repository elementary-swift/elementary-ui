import ElementaryUI
import Reactivity
import Testing

@testable import ElementaryWebComponents

@Suite
struct AttributeTests {
    @Test
    func macroMakesViewAndCollectsAttributeNames() {
        let view: any View = AttributeFixture()
        #expect(view is AttributeFixture)
        #expect(
            AttributeFixture.observedAttributes == [
                "count", "step-size", "label", "user-id", "url-value", "theme",
            ]
        )
    }

    @Test
    func attributesDecodeAndRestoreDefaults() {
        let fixture = AttributeFixture(count: 7)
        let host = Host(fixture)

        #expect(host.apply("count", "42"))
        #expect(host.apply("step-size", "3"))
        #expect(host.apply("label", "Hello"))
        #expect(host.apply("theme", "dark"))
        #expect(fixture.count == 42)
        #expect(fixture.stepSize == 3)
        #expect(fixture.label == "Hello")
        #expect(fixture.theme == .dark)

        #expect(host.apply("count", nil))
        #expect(host.apply("label", nil))
        #expect(host.apply("theme", nil))
        #expect(fixture.count == 7)
        #expect(fixture.label == nil)
        #expect(fixture.theme == .system)
    }

    @Test
    func invalidValuesPreserveCurrentValue() {
        let fixture = AttributeFixture()
        let host = Host(fixture)
        #expect(host.apply("count", "9"))
        #expect(!host.apply("count", "nine"))
        #expect(!host.apply("missing", "1"))
        #expect(fixture.count == 9)
    }

    @Test
    func textualBooleanRequiresExactLowercaseValues() {
        let attribute = Attribute(wrappedValue: false)
        let host = Host()
        host.link("flag", attribute)
        #expect(host.apply("flag", "true"))
        #expect(attribute.wrappedValue)
        #expect(host.apply("flag", "false"))
        #expect(!attribute.wrappedValue)
        for invalid in ["", "TRUE", "True", "FALSE", "False", " true", "false ", "1", "0", "trué"] {
            #expect(!host.apply("flag", invalid))
            #expect(!attribute.wrappedValue)
        }
    }

    @Test
    func attributeNamesUseExactUTF8Bytes() {
        let count = Attribute(wrappedValue: 0)
        let countHost = Host()
        countHost.link("count", count)
        #expect(countHost.apply("count", "3"))
        #expect(!countHost.apply("COUNT", "4"))
        #expect(!countHost.apply("", "1"))
        #expect(!countHost.apply("count\0", "1"))
        #expect(count.wrappedValue == 3)

        let fixture = UTF8AttributeFixture()
        let host = Host(fixture)
        #expect(host.apply("café", "7"))
        #expect(!host.apply("cafe\u{301}", "8"))
        #expect(fixture.value == 7)
    }

    @Test
    func builtInNumericTypesDecodeAttributeText() {
        #expect(Int.decodeAttribute("-1") == -1)
        #expect(Int8.decodeAttribute("-8") == -8)
        #expect(Int16.decodeAttribute("-16") == -16)
        #expect(Int32.decodeAttribute("-32") == -32)
        #expect(Int64.decodeAttribute("-64") == -64)
        #expect(UInt.decodeAttribute("1") == 1)
        #expect(UInt8.decodeAttribute("8") == 8)
        #expect(UInt16.decodeAttribute("16") == 16)
        #expect(UInt32.decodeAttribute("32") == 32)
        #expect(UInt64.decodeAttribute("64") == 64)
        #expect(Float.decodeAttribute("1.25") == 1.25)
        #expect(Double.decodeAttribute("2.5") == 2.5)
        #expect(UInt8.decodeAttribute("-1") == nil)
        #expect(Int8.decodeAttribute("128") == nil)
    }

    @Test
    func attributeChangesParticipateInReactivity() {
        let attribute = Attribute(wrappedValue: 1)
        let host = Host()
        host.link("count", attribute)
        nonisolated(unsafe) var changed = false

        withReactiveTracking {
            _ = attribute.wrappedValue
        } onChange: {
            changed = true
        }

        #expect(host.apply("count", "2"))
        #expect(changed)
        #expect(attribute.wrappedValue == 2)
    }

    @Test
    func directSwiftInitializationUsesTypedProperties() {
        let fixture = AttributeFixture(count: 7, stepSize: 4, theme: .dark)
        #expect(fixture.count == 7)
        #expect(fixture.stepSize == 4)
        #expect(fixture.theme == .dark)
        #expect((fixture.body as! StringContent).text == "7:4")
    }
}

private final class Host {
    private var context = _CustomElementHostContext()

    init() {}

    init(_ element: some CustomElement) {
        element.__applyCustomElementContext(&context)
    }

    func link(_ name: String, _ attribute: Attribute<some CustomElementAttributeValue>) {
        context.linkAttribute(name, attribute)
    }

    func apply(_ name: String, _ value: String?) -> Bool {
        context.trySetAttribute(name, value: value)
    }
}

private enum Theme: String, CustomElementAttributeValue {
    case system
    case dark
}

@CustomElement
private struct AttributeFixture {
    @Attribute var count = 1
    @Attribute("step-size") var stepSize = 2
    @Attribute var label: String?
    @Attribute var userID = "user"
    @Attribute var URLValue = "url"
    @Attribute var theme: Theme? = .system

    var body: some View {
        "\(count):\(stepSize)"
    }
}

@CustomElement
private struct UTF8AttributeFixture {
    @Attribute("café") var value = 0

    var body: some View { "\(value)" }
}
