import Testing

@testable import ElementaryUI

// NOTE: unfortunately, we cannot really test if the JSString's are the same "instance"
// without running in a JS environment

@Suite
struct StaticJSStringCacheTests {
    @Test
    func reusesCachedEntryForSameUTF8Content() {
        let cache = StaticJSStringCache()

        let s1 = cache.getOrAddStaticString("div")

        let reconstructed = String(["d", "i", "v"])
        let s2 = cache.getOrAddStaticString(reconstructed)

        #expect(s1.description == "div")
        #expect(s2.description == "div")
        #expect(cache.count == 1)
    }

    @Test
    func doesNotGrowBeyondCapacity() {
        let cache = StaticJSStringCache()

        for i in 0..<512 {
            _ = cache.getOrAddStaticString("key-\(i)")
        }
        #expect(cache.count == 512)

        _ = cache.getOrAddStaticString("overflow-a")
        _ = cache.getOrAddStaticString("overflow-b")
        _ = cache.getOrAddStaticString("overflow-a")

        #expect(cache.count == 512)
    }

    @Test
    func stillServesExistingEntriesWhenFull() {
        let cache = StaticJSStringCache()

        for i in 0..<512 {
            _ = cache.getOrAddStaticString("key-\(i)")
        }

        let jsString = cache.getOrAddStaticString("key-42")

        #expect(jsString.description == "key-42")
        #expect(cache.count == 512)
    }
}
