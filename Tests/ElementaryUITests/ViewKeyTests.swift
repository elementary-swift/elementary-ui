import Testing

@testable import ElementaryUI

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
    func arbitraryHashableValuesUseTypedEquality() {
        struct Point: Hashable { var x: Int, y: Int }
        struct Other: Hashable { var x: Int, y: Int }

        #expect(_ViewKey(Point(x: 1, y: 2)) == _ViewKey(Point(x: 1, y: 2)))
        #expect(_ViewKey(Point(x: 1, y: 2)).hashValue == _ViewKey(Point(x: 1, y: 2)).hashValue)
        #expect(_ViewKey(Point(x: 1, y: 2)) != _ViewKey(Point(x: 2, y: 1)))
        #expect(_ViewKey(Point(x: 1, y: 2)) != _ViewKey(Other(x: 1, y: 2)))
    }

    @Test
    func genericStringAndIntValuesMatchConcreteKeys() {
        func key<T: Hashable>(_ value: T) -> _ViewKey { _ViewKey(value) }

        #expect(key("a") == _ViewKey("a"))
        #expect(key(1) == _ViewKey(1))
        #expect(key("1") != key(1))
    }

    @Test
    func utf8KeysCompareByDescription() {
        #expect(_ViewKey(_UTF8Key(1)) == _ViewKey(_UTF8Key("1")))
        #expect(_ViewKey(_UTF8Key("a")) != _ViewKey(_UTF8Key("b")))
        #expect(_ViewKey(_UTF8Key("1")) != _ViewKey("1"))
    }

    @Test
    func numericDescriptionUsesNumberStringValue() {
        #expect(_ViewKey(42).description == "42")
    }
}
