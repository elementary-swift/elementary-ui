@_spi(BridgeJS) import JavaScriptKit

/// JavaScript's built-in `Math` namespace.
@JSClass(jsName: "Math", from: .global)
public struct JSMath {
    @JSFunction public static func cos(_ value: Double) throws(JSException) -> Double
    @JSFunction public static func sin(_ value: Double) throws(JSException) -> Double
    @JSFunction public static func pow(_ base: Double, _ exponent: Double) throws(JSException) -> Double
    @JSFunction public static func exp(_ value: Double) throws(JSException) -> Double
    @JSFunction public static func log(_ value: Double) throws(JSException) -> Double
}
