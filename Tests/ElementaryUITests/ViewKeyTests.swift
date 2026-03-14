import ElementaryUI
import Testing

@Suite
struct ViewKeyTests {
    @Test
    func sameStringIsEqual() {
        let a = _ViewKey("hello")
        let b = _ViewKey("hello")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func differentStringsAreNotEqual() {
        let a = _ViewKey("a")
        let b = _ViewKey("b")
        #expect(a != b)
        #expect(a.hashValue != b.hashValue)
    }
    @Test
    func stringValueRoundtrip() {
        let s = "hello world"
        let view = _ViewKey(s)
        #expect(view.description == s)
    }

    @Test
    func strictTypedEqualityForTextAndNumber() {
        #expect(_ViewKey("1") != _ViewKey(1))
        #expect(_ViewKey(1) == _ViewKey(1))
    }

    @Test
    func hashDistinguishesTextAndNumberRepresentations() {
        let keys: Set<_ViewKey> = [_ViewKey("1"), _ViewKey(1), _ViewKey(2), _ViewKey("2")]
        #expect(keys.count == 4)
    }

    @Test
    func numericDescriptionUsesNumberStringValue() {
        #expect(_ViewKey(42).description == "42")
    }
}
