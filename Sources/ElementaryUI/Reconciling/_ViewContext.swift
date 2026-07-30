// TODO: think about a better name for this... maybe _EnvironmentContext?
public struct _ViewContext {
    var environment: EnvironmentValues = .init()

    // built-in typed environment values (maybe using plain-old keys might be better?)
    var modifiers: DOMElementModifiers = .init()
    var layoutObservers: DOMLayoutObservers = .init()
    var transition: _TransitionState?
    var functionDepth: Int = 0

    mutating func takeModifiers() -> [any DOMElementModifier] {
        modifiers.take()
    }

    mutating func takeLayoutObservers() -> [DOMLayoutObserver] {
        layoutObservers.take()
    }

    public static var empty: Self {
        .init()
    }
}
