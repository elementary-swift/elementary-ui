public protocol __FunctionView: _Mountable, MarkupContent where Body: _Mountable {
    associatedtype __ViewState

    static func __initializeState(from view: borrowing Self) -> __ViewState
    static func __restoreState(_ storage: __ViewState, in view: inout Self)

    static func __applyContext(_ context: borrowing _ViewContext, to view: inout Self)

    static func __areEqual(a: borrowing Self, b: borrowing Self) -> Bool
}

public extension __FunctionView {

    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _FunctionNode<Self> {
        _FunctionNode(value: view, context: context, ctx: &ctx)
    }

    static func _patchNode(
        _ view: consuming Self,
        node: inout _FunctionNode<Self>,
        tx: inout _TransactionContext
    ) {
        node.patch(view, tx: &tx)
    }
}

public extension __FunctionView {
    static func __initializeState(from view: borrowing Self) {}
    static func __restoreState(_ storage: __ViewState, in view: inout Self) {}
}

public extension __FunctionView where Self: Animatable {
    static func _makeNode(
        _ view: consuming Self,
        context: borrowing _ViewContext,
        ctx: inout _MountContext
    ) -> _AnimatableFunctionNode<Self> {
        _AnimatableFunctionNode(value: view, context: context, ctx: &ctx)
    }

    static func _patchNode(
        _ view: consuming Self,
        node: inout _AnimatableFunctionNode<Self>,
        tx: inout _TransactionContext
    ) {
        node.patch(view, tx: &tx)
    }
}

public extension __FunctionView {
    static func __areEqual(a: borrowing Self, b: borrowing Self) -> Bool where Self: Equatable {
        a == b
    }

    static func __areEqual(a: borrowing Self, b: Self) -> Bool where Self: __ViewEquatable {
        Self.__arePropertiesEqual(a: a, b: b)
    }

    static func __areEqual(a: borrowing Self, b: borrowing Self) -> Bool where Self: Equatable & __ViewEquatable {
        // that is the question.... but I think if explicit equality is provided, we should use it
        a == b
    }

    static func __areEqual(a: borrowing Self, b: borrowing Self) -> Bool {
        false
    }
}
