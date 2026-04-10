import Reactivity
import Testing

@Suite
struct PropertyIDTests {
    @Test
    func hashAndEqualityDistinguishStringAndIndexIdentifiers() {
        #expect(PropertyID("1") != PropertyID(1))

        let ids: Set<PropertyID> = [
            PropertyID("1"),
            PropertyID(1),
            PropertyID("2"),
            PropertyID(2),
        ]

        #expect(ids.count == 4)
    }
}
