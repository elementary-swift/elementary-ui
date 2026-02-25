import Reactivity
import Testing

@Suite
struct HashableUTF8ViewTests {

    @Test
    func sameStringIsEqual() {
        let a = HashableUTF8View("hello")
        let b = HashableUTF8View("hello")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func differentStringsAreNotEqual() {
        let a = HashableUTF8View("a")
        let b = HashableUTF8View("b")
        #expect(a != b)
        #expect(a.hashValue != b.hashValue)
    }

    @Test
    func differentStringsHaveDifferentHashes() {
        let strings = ["", "a", "b", "hello", "world", "foo", "bar"]
        let set = Set(strings.map { HashableUTF8View($0) })
        #expect(set.count == strings.count)
    }

    @Test
    func stringValueRoundtrip() {
        let s = "hello world"
        let view = HashableUTF8View(s)
        #expect(view.stringValue == s)
    }
}
