import ElementaryUI
import ElementaryWebComponents
import Reactivity
import Testing

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
        let storage = mount(fixture)

        #expect(storage.apply(name: "count", value: "42"))
        #expect(storage.apply(name: "step-size", value: "3"))
        #expect(storage.apply(name: "label", value: "Hello"))
        #expect(storage.apply(name: "theme", value: "dark"))
        #expect(fixture.count == 42)
        #expect(fixture.stepSize == 3)
        #expect(fixture.label == "Hello")
        #expect(fixture.theme == .dark)

        #expect(storage.apply(name: "count", value: nil))
        #expect(storage.apply(name: "label", value: nil))
        #expect(storage.apply(name: "theme", value: nil))
        #expect(fixture.count == 1)
        #expect(fixture.label == nil)
        #expect(fixture.theme == .system)
    }

    @Test
    func invalidValuesPreserveCurrentValue() {
        let fixture = AttributeFixture()
        let storage = mount(fixture)
        #expect(storage.apply(name: "count", value: "9"))
        #expect(!storage.apply(name: "count", value: "nine"))
        #expect(!storage.apply(name: "missing", value: "1"))
        #expect(fixture.count == 9)
    }

    @Test
    func textualBooleanRequiresExactLowercaseValues() {
        let attribute = Attribute(wrappedValue: false)
        let storage = _CustomElementAttributeStorage([
            attribute.slot(named: "flag", declarationDefault: false)
        ])
        #expect(storage.apply(name: "flag", value: "true"))
        #expect(attribute.wrappedValue)
        #expect(storage.apply(name: "flag", value: "false"))
        #expect(!attribute.wrappedValue)
        for invalid in ["", "TRUE", "True", "FALSE", "False", " true", "false ", "1", "0", "trué"] {
            #expect(!storage.apply(name: "flag", value: invalid))
            #expect(!attribute.wrappedValue)
        }
    }

    @Test
    func attributeNamesUseExactUTF8Bytes() {
        let count = Attribute(wrappedValue: 0)
        let countStorage = _CustomElementAttributeStorage([
            count.slot(named: "count", declarationDefault: 0)
        ])
        #expect(countStorage.apply(name: "count", value: "3"))
        #expect(!countStorage.apply(name: "COUNT", value: "4"))
        #expect(!countStorage.apply(name: "", value: "1"))
        #expect(!countStorage.apply(name: "count\0", value: "1"))
        #expect(count.wrappedValue == 3)

        let fixture = UTF8AttributeFixture()
        let storage = UTF8AttributeFixture.__attributes(from: fixture)
        #expect(storage.apply(name: "café", value: "7"))
        #expect(!storage.apply(name: "cafe\u{301}", value: "8"))
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
        let storage = _CustomElementAttributeStorage([
            attribute.slot(named: "count", declarationDefault: 1)
        ])
        nonisolated(unsafe) var changed = false

        withReactiveTracking {
            _ = attribute.wrappedValue
        } onChange: {
            changed = true
        }

        #expect(storage.apply(name: "count", value: "2"))
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

private enum Theme: String, CustomElementAttributeValue {
    case system
    case dark
}

private struct AttributeFixture {
    @Attribute var count = 1
    @Attribute("step-size") var stepSize = 2
    @Attribute var label: String?
    @Attribute var userID = "user"
    @Attribute var URLValue = "url"
    @Attribute var theme: Theme? = .system

    @ContentBuilder var body: some View {
        "\(count):\(stepSize)"
    }

    static var observedAttributes: [String] {
        ["count", "step-size", "label", "user-id", "url-value", "theme"]
    }

    static func __attributes(from view: borrowing Self) -> _CustomElementAttributeStorage {
        _CustomElementAttributeStorage([
            view._count.slot(named: "count", declarationDefault: 1),
            view._stepSize.slot(named: "step-size", declarationDefault: 2),
            view._label.slot(named: "label", declarationDefault: nil),
            view._userID.slot(named: "user-id", declarationDefault: "user"),
            view._URLValue.slot(named: "url-value", declarationDefault: "url"),
            view._theme.slot(named: "theme", declarationDefault: .system),
        ])
    }
}

private func mount(_ fixture: AttributeFixture) -> _CustomElementAttributeStorage {
    AttributeFixture.__attributes(from: fixture)
}

extension AttributeFixture: __FunctionView, View {
    static func __applyContext(_ context: borrowing _ViewContext, to view: inout Self) {

    }
    typealias __ViewState = Void
}

extension AttributeFixture: __ViewEquatable {
    static func __arePropertiesEqual(a: Self, b: Self) -> Bool {
        true
            && __ViewProperty.areKnownEqual(a.count, b.count)
            && __ViewProperty.areKnownEqual(a.stepSize, b.stepSize)
            && __ViewProperty.areKnownEqual(a.label, b.label)
            && __ViewProperty.areKnownEqual(a.userID, b.userID)
            && __ViewProperty.areKnownEqual(a.URLValue, b.URLValue)
            && __ViewProperty.areKnownEqual(a.theme, b.theme)
    }
}

extension AttributeFixture: CustomElement {
}

@CustomElement
private struct UTF8AttributeFixture {
    @Attribute("café") var value = 0

    var body: some View { "\(value)" }
}
