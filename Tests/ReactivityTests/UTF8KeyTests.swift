import Testing
import _UTF8Internals

@Suite
struct UTF8KeyTests {

    @Test
    func sameStringIsEqual() {
        let a = UTF8Key("hello")
        let b = UTF8Key("hello")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func differentStringsAreNotEqual() {
        let a = UTF8Key("a")
        let b = UTF8Key("b")
        #expect(a != b)
        #expect(a.hashValue != b.hashValue)
    }

    @Test
    func differentStringsHaveDifferentHashes() {
        let strings = ["", "a", "b", "hello", "world", "foo", "bar"]
        let set = Set(strings.map { UTF8Key($0) })
        #expect(set.count == strings.count)
    }

    @Test
    func stringValueRoundtrip() {
        let string = "hello world"
        let key = UTF8Key(string)
        #expect(key.stringValue == string)
    }
}
