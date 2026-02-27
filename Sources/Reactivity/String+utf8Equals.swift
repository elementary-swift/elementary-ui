// NOTE: tests were done with Swift Span loops, SIMD loops span+memcmp, and memcmp directly on string buffer
// the winner was memcmp directly on string buffer - plain Span loops were also pretty fast
// non-contiguous storage is not supported and probably won't matter much...

// TODO: move this to a nicer place
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported platform")
#endif

extension String {
    @inline(__always)
    @inlinable
    package func _utf8Equals(_ other: borrowing String) -> Bool {
        guard self.isContiguousUTF8 && other.isContiguousUTF8 else {
            return self.utf8.elementsEqual(other.utf8)
        }

        return self.utf8.withContiguousStorageIfAvailable { lhs in
            other.utf8.withContiguousStorageIfAvailable { rhs in
                guard lhs.count == rhs.count else { return false }
                return memcmp(lhs.baseAddress!, rhs.baseAddress!, lhs.count) == 0
            }!
        }!
    }
}

extension Substring.UTF8View {
    @inline(__always)
    @inlinable
    package func _utf8Equals(_ other: borrowing Substring.UTF8View) -> Bool {
        self.withContiguousStorageIfAvailable { lhs in
            other.withContiguousStorageIfAvailable { rhs in
                guard lhs.count == rhs.count else { return false }
                return memcmp(lhs.baseAddress!, rhs.baseAddress!, lhs.count) == 0
            }!
        }!
    }
}

// @inlinable
// func spancmp(_ lhs: Span<UInt8>, _ rhs: Span<UInt8>) -> Bool {
//     guard lhs.count == rhs.count else { return false }
//     guard !lhs.isIdentical(to: rhs) else { return true }

//     for i in 0..<lhs.count {
//         guard lhs[unchecked: i] == rhs[unchecked: i] else { return false }
//     }

//     return true
// }

// @inlinable
// func spancmp(_ lhs: Span<UInt8>, _ rhs: Span<UInt8>) -> Bool {
//     let count = lhs.count
//     guard count == rhs.count else { return false }
//     guard !lhs.isIdentical(to: rhs) else { return true }

//     let lBytes = RawSpan(_elements: lhs)
//     let rBytes = RawSpan(_elements: rhs)

//     let simdWidth = MemoryLayout<SIMD16<UInt8>>.size
//     let simdEnd = count & ~(simdWidth - 1)

//     var i = 0
//     while i < simdEnd {
//         let lChunk: SIMD16<UInt8> = lBytes.unsafeLoadUnaligned(fromUncheckedByteOffset: i, as: SIMD16<UInt8>.self)
//         let rChunk: SIMD16<UInt8> = rBytes.unsafeLoadUnaligned(fromUncheckedByteOffset: i, as: SIMD16<UInt8>.self)
//         guard lChunk == rChunk else { return false }
//         i += simdWidth
//     }

//     while i < count {
//         guard lhs[unchecked: i] == rhs[unchecked: i] else { return false }
//         i += 1
//     }

//     return true
// }
