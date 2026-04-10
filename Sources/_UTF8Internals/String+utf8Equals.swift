// NOTE: tests were done with Swift Span loops, SIMD loops span+memcmp, and memcmp directly on string buffer.
// The winner was memcmp directly on string buffer. Plain Span loops were also pretty fast.
// Non-contiguous storage is not supported as a dedicated fast path and falls back to a copied buffer.

#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported platform")
#endif

@inline(__always)
@inlinable
package func _withUTF8Buffer<R>(
    _ string: borrowing String,
    _ body: (UnsafeBufferPointer<UInt8>) -> R
) -> R {
    if string.isContiguousUTF8 {
        return string.utf8.withContiguousStorageIfAvailable(body)!
    }

    let copy = Array(string.utf8)
    return copy.withUnsafeBufferPointer(body)
}

@inline(__always)
@inlinable
package func _withUTF8Buffer<R>(
    _ utf8: Substring.UTF8View,
    _ body: (UnsafeBufferPointer<UInt8>) -> R
) -> R {
    if let result = utf8.withContiguousStorageIfAvailable(body) {
        return result
    }

    let copy = Array(utf8)
    return copy.withUnsafeBufferPointer(body)
}

@inline(__always)
@inlinable
package func _utf8BuffersEqual(
    _ lhs: UnsafeBufferPointer<UInt8>,
    _ rhs: UnsafeBufferPointer<UInt8>
) -> Bool {
    guard lhs.count == rhs.count else { return false }
    guard lhs.count > 0 else { return true }
    return memcmp(lhs.baseAddress!, rhs.baseAddress!, lhs.count) == 0
}

@inline(__always)
@inlinable
package func _hashUTF8Buffer(
    _ buffer: UnsafeBufferPointer<UInt8>,
    into hasher: inout Hasher
) {
    let rawBuffer = UnsafeRawBufferPointer(start: buffer.baseAddress, count: buffer.count)
    hasher.combine(bytes: rawBuffer)
}

@inline(__always)
@inlinable
package func _utf8Equals(
    _ lhs: borrowing String,
    _ rhs: borrowing Substring.UTF8View
) -> Bool {
    _withUTF8Buffer(lhs) { lhsBuffer in
        _withUTF8Buffer(rhs) { rhsBuffer in
            _utf8BuffersEqual(lhsBuffer, rhsBuffer)
        }
    }
}

extension String {
    @inline(__always)
    @inlinable
    package borrowing func utf8Equals(_ other: borrowing String) -> Bool {
        _withUTF8Buffer(self) { lhsBuffer in
            _withUTF8Buffer(other) { rhsBuffer in
                _utf8BuffersEqual(lhsBuffer, rhsBuffer)
            }
        }
    }

    @inline(__always)
    @inlinable
    package static func utf8Equals(_ lhs: borrowing String, _ rhs: borrowing String) -> Bool {
        lhs.utf8Equals(rhs)
    }
}

extension String? {
    @inline(__always)
    @inlinable
    package func utf8Equals(_ other: String?) -> Bool {
        switch (self, other) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return lhs.utf8Equals(rhs)
        default:
            return false
        }
    }
}

extension Substring.UTF8View {
    @inline(__always)
    @inlinable
    package func _utf8Equals(_ other: borrowing Substring.UTF8View) -> Bool {
        _withUTF8Buffer(self) { lhsBuffer in
            _withUTF8Buffer(other) { rhsBuffer in
                _utf8BuffersEqual(lhsBuffer, rhsBuffer)
            }
        }
    }
}
