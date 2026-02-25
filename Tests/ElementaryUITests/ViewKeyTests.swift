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
}
