import JavaScriptKit

@JSGetter(from: .global)
public var window: JSWindow

@JSGetter(from: .global)
public var document: JSDocument

@JSGetter(from: .global)
public var performance: JSPerformance

@JSFunction(from: .global)
public func requestAnimationFrame(_ callback: @escaping (Double) -> Void) throws(JSException) -> Double

@JSFunction(from: .global)
public func cancelAnimationFrame(_ handle: Double) throws(JSException)

@JSFunction(from: .global)
public func queueMicrotask(_ callback: @escaping () -> Void) throws(JSException)

@JSFunction(from: .global)
public func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double) throws(JSException)
