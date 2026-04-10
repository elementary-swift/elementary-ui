import JavaScriptKit
import _UTF8Internals

/// A never-expiring cache of static JS strings.
final class StaticJSStringCache {
    private var cache = [UTF8Key: JSString]()
    private var hasWarned = false

    var count: Int {
        cache.count
    }

    init() {}

    func getOrAddStaticString(_ string: String) -> JSString {
        let key = UTF8Key(string)

        if let cached = cache[key] {
            return cached
        }

        if cache.count >= 512 {
            if !hasWarned {
                logWarning("Static JS string cache is full. count: \(cache.count)")
                hasWarned = true
            }
            return JSString(string)
        }

        logTrace("adding \(string) to cache. count: \(cache.count)")
        let jsString = JSString(string)
        cache[key] = jsString

        return jsString
    }
}
