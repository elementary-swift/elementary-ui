import JavaScriptKit

import struct Reactivity.HashableUTF8View

final class StaticJSStringCache {
    private var cache = [HashableUTF8View: JSString]()
    private var hasWarned = false

    init() {}

    func get(_ string: String) -> JSString {
        let key = HashableUTF8View(string)

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
