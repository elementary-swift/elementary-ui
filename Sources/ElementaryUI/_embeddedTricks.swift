// FIXME: embedded - create issue and check with main
// we need to force addition of types that are present in unused enum cases -> otherwise it crashes the compiler (6.2 at least)
#if hasFeature(Embedded)
internal var __omg_this_was_annoying_I_am_false: Bool = false
#endif

// FIXME: embedded - remove once https://github.com/swiftlang/swift/issues/83460 lands
// also, implementation is AI slop, I would not trust it with anything
#if hasFeature(Embedded) && compiler(<6.3)
@_silgen_name("swift_float32ToString")
@_noAllocation
public func _swift_float32ToString(
    _ buffer: UnsafeMutablePointer<UInt8>,
    _ bufferLength: UInt,
    _ value: Float,
    _ isDebug: Bool
) -> UInt64 {
    _swift_float64ToString(buffer, bufferLength, Double(value), isDebug)
}

@_silgen_name("swift_float64ToString")
@_noAllocation
public func _swift_float64ToString(
    _ buffer: UnsafeMutablePointer<UInt8>,
    _ bufferLength: UInt,
    _ value: Double,
    _ isDebug: Bool
) -> UInt64 {
    var value = value
    var index = 0
    let maxIndex = Int(bufferLength) - 1

    if value < 0 {
        if index > maxIndex { return 0 }
        buffer[index] = 45  // '-'
        index += 1
        value = -value
    }

    // Handle non-finite values early
    if value.isNaN {
        if index > maxIndex { return UInt64(index) }
        buffer[index] = 110  // 'n'
        index += 1
        if index > maxIndex { return UInt64(index) }
        buffer[index] = 97  // 'a'
        index += 1
        if index > maxIndex { return UInt64(index) }
        buffer[index] = 110  // 'n'
        index += 1
        return UInt64(index)
    }

    if !value.isFinite {
        if index > maxIndex { return UInt64(index) }
        buffer[index] = 105  // 'i'
        index += 1
        if index > maxIndex { return UInt64(index) }
        buffer[index] = 110  // 'n'
        index += 1
        if index > maxIndex { return UInt64(index) }
        buffer[index] = 102  // 'f'
        index += 1
        return UInt64(index)
    }

    // Use scientific notation for very large/small magnitudes or when Int conversion may overflow
    let absValue = value
    var useScientific = false
    if absValue != 0 {
        if absValue >= 1_000_000 || absValue < 0.0001 {
            useScientific = true
        }
        if absValue > Double(Int.max) {
            useScientific = true
        }
    }

    if useScientific {
        var mantissa = absValue
        var exponent = 0
        if mantissa != 0 {
            while mantissa >= 10 {
                mantissa /= 10
                exponent += 1
            }
            while mantissa < 1 {
                mantissa *= 10
                exponent -= 1
            }
        }

        // Calculate how many fractional digits we can fit before the exponent
        // respecting a 10 significant digit limit (1 leading + up to 9 fractional)
        var expAbs = exponent >= 0 ? exponent : -exponent
        var expDigits = 1
        var tmpExp = expAbs
        while tmpExp >= 10 {
            tmpExp /= 10
            expDigits += 1
        }
        let reservedForExponent = expDigits + 2  // 'e' + sign
        let remainingBeforeExponent = (maxIndex - index) - reservedForExponent
        let capacityBasedFractionals = max(0, remainingBeforeExponent - 2)  // leading + dot
        let digitBasedFractionals = 9
        let allowedFractionDigitsSci = max(0, min(digitBasedFractionals, capacityBasedFractionals))

        // Round mantissa to allowed fractional digits to avoid carry overflow when writing
        var scale: Double = 1
        if allowedFractionDigitsSci > 0 {
            for _ in 0..<allowedFractionDigitsSci { scale *= 10 }
        }
        if allowedFractionDigitsSci > 0 {
            let roundedTimes = (mantissa * scale + 0.5).rounded(.down)
            mantissa = roundedTimes / scale
            if mantissa >= 10 {
                mantissa /= 10
                exponent += 1
                // recompute exponent reservation if it grew in digits
                expAbs = exponent >= 0 ? exponent : -exponent
                expDigits = 1
                tmpExp = expAbs
                while tmpExp >= 10 {
                    tmpExp /= 10
                    expDigits += 1
                }
            }
        }

        // Write single leading digit of mantissa
        let leadingDigit = Int(mantissa)
        if index > maxIndex { return UInt64(index) }
        buffer[index] = UInt8(leadingDigit) + 48
        index += 1

        // Fractional part of mantissa
        let fractionalPartSci = mantissa - Double(leadingDigit)
        if allowedFractionDigitsSci > 0 && fractionalPartSci > 0 {
            if index > maxIndex { return UInt64(index) }
            buffer[index] = 46  // '.'
            index += 1

            var remaining = fractionalPartSci
            var decimalPlaces = 0
            var hasNonZeroDigit = false

            while decimalPlaces < allowedFractionDigitsSci && index <= maxIndex {
                remaining *= 10
                let digit = Int(remaining)
                buffer[index] = UInt8(digit) + 48
                index += 1
                remaining -= Double(digit)
                decimalPlaces += 1
                if digit != 0 {
                    hasNonZeroDigit = true
                }
            }

            // Round last digit
            if index <= maxIndex {
                remaining *= 10
                let nextDigit = Int(remaining)
                if nextDigit >= 5 {
                    var i = index - 1
                    while i >= 0 {
                        if buffer[i] == 46 {  // '.'
                            i -= 1
                            continue
                        }
                        if buffer[i] < 57 {  // '9'
                            buffer[i] += 1
                            break
                        } else {
                            buffer[i] = 48  // '0'
                            i -= 1
                        }
                    }
                }
            }

            if hasNonZeroDigit {
                while index > 0 && buffer[index - 1] == 48 {  // '0'
                    index -= 1
                }
                if index > 0 && buffer[index - 1] == 46 {  // '.'
                    index -= 1
                }
            }
        }

        // Write exponent part: 'e' + sign + digits
        if index > maxIndex { return UInt64(index) }
        buffer[index] = 101  // 'e'
        index += 1

        var exp = exponent
        var expIsNegative = false
        if exp < 0 {
            expIsNegative = true
            exp = -exp
        }

        if index > maxIndex { return UInt64(index) }
        buffer[index] = expIsNegative ? 45 : 43  // '-' or '+'
        index += 1

        // Write exponent digits
        var expTemp = exp
        let expStart = index
        if expTemp == 0 {
            if index > maxIndex { return UInt64(index) }
            buffer[index] = 48  // '0'
            index += 1
        } else {
            while expTemp > 0 {
                if index > maxIndex { return UInt64(index) }
                let digit = UInt8(expTemp % 10) + 48
                buffer[index] = digit
                index += 1
                expTemp /= 10
            }
            // reverse exponent digits
            var i = expStart
            var j = index - 1
            while i < j {
                let t = buffer[i]
                buffer[i] = buffer[j]
                buffer[j] = t
                i += 1
                j -= 1
            }
        }

        return UInt64(index)
    }

    let integerPart = Int(value)
    var temp = integerPart
    let start = index
    if temp == 0 {
        if index > maxIndex { return UInt64(index) }
        buffer[index] = 48  // '0'
        index += 1
    } else {
        while temp > 0 {
            if index > maxIndex { return UInt64(index) }
            let digit = UInt8(temp % 10) + 48  // ASCII '0' is 48
            buffer[index] = digit
            index += 1
            temp /= 10
        }
        // reverse the integer digits written in place
        var i = start
        var j = index - 1
        while i < j {
            let t = buffer[i]
            buffer[i] = buffer[j]
            buffer[j] = t
            i += 1
            j -= 1
        }
    }

    let fractionalPart = value - Double(integerPart)
    if fractionalPart > 0 {
        // Determine how many fractional digits we can print based on buffer and 10-digit significant cap
        let integerDigits = index - start
        let remainingCapacity = maxIndex - index
        let capacityBasedFractionals = max(0, remainingCapacity - 1)  // dot
        let digitBasedFractionals = max(0, 10 - integerDigits)
        let allowedFractionDigits = max(0, min(digitBasedFractionals, capacityBasedFractionals))

        if allowedFractionDigits > 0 {
            if index > maxIndex { return UInt64(index) }
            buffer[index] = 46  // '.'
            index += 1

            var remaining = fractionalPart
            var decimalPlaces = 0
            var hasNonZeroDigit = false

            while decimalPlaces < allowedFractionDigits && index <= maxIndex {
                remaining *= 10
                let digit = Int(remaining)
                buffer[index] = UInt8(digit) + 48
                index += 1
                remaining -= Double(digit)
                decimalPlaces += 1
                if digit != 0 {
                    hasNonZeroDigit = true
                }
            }

            // Check if we need to round up
            if index <= maxIndex {
                remaining *= 10
                let nextDigit = Int(remaining)
                if nextDigit >= 5 {
                    // Round up the last digit
                    var i = index - 1
                    while i >= 0 {
                        if buffer[i] == 46 {  // skip the decimal point
                            i -= 1
                            continue
                        }
                        if buffer[i] < 57 {  // '9'
                            buffer[i] += 1
                            break
                        } else {
                            buffer[i] = 48  // '0'
                            i -= 1
                        }
                    }
                }
            }

            // Only remove trailing zeros if there are non-zero digits after the decimal point
            if hasNonZeroDigit {
                while index > 0 && buffer[index - 1] == 48 {  // '0'
                    index -= 1
                }
                if index > 0 && buffer[index - 1] == 46 {  // '.'
                    index -= 1
                }
            }
        }
    }

    return UInt64(index)
}
#endif
