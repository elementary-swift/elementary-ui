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

        #expect(fixture.setAttribute(name: "count", value: "42"))
        #expect(fixture.setAttribute(name: "step-size", value: "3"))
        #expect(fixture.setAttribute(name: "label", value: "Hello"))
        #expect(fixture.setAttribute(name: "theme", value: "dark"))
        #expect(fixture.count == 42)
        #expect(fixture.stepSize == 3)
        #expect(fixture.label == "Hello")
        #expect(fixture.theme == .dark)

        #expect(fixture.setAttribute(name: "count", value: nil))
        #expect(fixture.setAttribute(name: "label", value: nil))
        #expect(fixture.setAttribute(name: "theme", value: nil))
        #expect(fixture.count == 1)
        #expect(fixture.label == nil)
        #expect(fixture.theme == .system)
    }

    @Test
    func invalidValuesPreserveCurrentValue() {
        let fixture = AttributeFixture()
        #expect(fixture.setAttribute(name: "count", value: "9"))
        #expect(!fixture.setAttribute(name: "count", value: "nine"))
        #expect(!fixture.setAttribute(name: "missing", value: "1"))
        #expect(fixture.count == 9)
    }

    @Test
    func textualBooleanIsCaseInsensitiveAndNotPresenceBased() {
        let attribute = Attribute(wrappedValue: false)
        #expect(attribute._setAttributeValue("TRUE"))
        #expect(attribute.wrappedValue)
        #expect(attribute._setAttributeValue("false"))
        #expect(!attribute.wrappedValue)
        #expect(!attribute._setAttributeValue(""))
        #expect(!attribute.wrappedValue)
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
        nonisolated(unsafe) var changed = false

        withReactiveTracking {
            _ = attribute.wrappedValue
        } onChange: {
            changed = true
        }

        #expect(attribute._setAttributeValue("2"))
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

    func setAttribute(name: String, value: String?) -> Bool {
        switch name {
        case "count":
            guard let value else {
                self._count.wrappedValue = 1
                return true
            }
            return self._count._setAttributeValue(value)
        case "step-size":
            guard let value else {
                self._stepSize.wrappedValue = 2
                return true
            }
            return self._stepSize._setAttributeValue(value)
        case "label":
            guard let value else {
                self._label.wrappedValue = nil
                return true
            }
            return self._label._setAttributeValue(value)
        case "user-id":
            guard let value else {
                self._userID.wrappedValue = "user"
                return true
            }
            return self._userID._setAttributeValue(value)
        case "url-value":
            guard let value else {
                self._URLValue.wrappedValue = "url"
                return true
            }
            return self._URLValue._setAttributeValue(value)
        case "theme":
            guard let value else {
                self._theme.wrappedValue = .system
                return true
            }
            return self._theme._setAttributeValue(value)
        default:
            return false
        }
    }
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
