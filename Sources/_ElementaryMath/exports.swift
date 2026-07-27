#if os(WASI)
import BrowserInterop

@_cdecl("cos")
public func cos(_ x: Double) -> Double {
    try! JSMath.cos(x)
}

@_cdecl("sin")
public func sin(_ x: Double) -> Double {
    try! JSMath.sin(x)
}

@_cdecl("pow")
public func pow(_ x: Double, _ y: Double) -> Double {
    try! JSMath.pow(x, y)
}

@_cdecl("exp")
public func exp(_ x: Double) -> Double {
    try! JSMath.exp(x)
}

@_cdecl("log")
public func log(_ x: Double) -> Double {
    try! JSMath.log(x)
}
#else
@_extern(c) public func cos(_ x: Double) -> Double
@_extern(c) public func sin(_ x: Double) -> Double
@_extern(c) public func pow(_ x: Double, _ y: Double) -> Double
@_extern(c) public func exp(_ x: Double) -> Double
@_extern(c) public func log(_ x: Double) -> Double
#endif
