// FIXME: NONCOPYABLE tuples currently do not support ~Copyable
public struct _TupleNode<each N: _Reconcilable>: _Reconcilable {
    var value: (repeat each N)

    init(_ value: repeat each N) {
        self.value = (repeat each value)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        for value in repeat each value {
            value.unmount(&context)
        }
    }
}

public struct _TupleNode2<N0: _Reconcilable, N1: _Reconcilable>: _Reconcilable {
    var value: (N0, N1)

    init(_ n0: N0, _ n1: N1) {
        self.value = (n0, n1)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        value.0.unmount(&context)
        value.1.unmount(&context)
    }
}

public struct _TupleNode3<N0: _Reconcilable, N1: _Reconcilable, N2: _Reconcilable>: _Reconcilable {
    var value: (N0, N1, N2)

    init(_ n0: N0, _ n1: N1, _ n2: N2) {
        self.value = (n0, n1, n2)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        value.0.unmount(&context)
        value.1.unmount(&context)
        value.2.unmount(&context)
    }
}

public struct _TupleNode4<N0: _Reconcilable, N1: _Reconcilable, N2: _Reconcilable, N3: _Reconcilable>: _Reconcilable {
    var value: (N0, N1, N2, N3)

    init(_ n0: N0, _ n1: N1, _ n2: N2, _ n3: N3) {
        self.value = (n0, n1, n2, n3)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        value.0.unmount(&context)
        value.1.unmount(&context)
        value.2.unmount(&context)
        value.3.unmount(&context)
    }
}

public struct _TupleNode5<N0: _Reconcilable, N1: _Reconcilable, N2: _Reconcilable, N3: _Reconcilable, N4: _Reconcilable>:
    _Reconcilable
{
    var value: (N0, N1, N2, N3, N4)

    init(_ n0: N0, _ n1: N1, _ n2: N2, _ n3: N3, _ n4: N4) {
        self.value = (n0, n1, n2, n3, n4)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        value.0.unmount(&context)
        value.1.unmount(&context)
        value.2.unmount(&context)
        value.3.unmount(&context)
        value.4.unmount(&context)
    }
}

public struct _TupleNode6<
    N0: _Reconcilable,
    N1: _Reconcilable,
    N2: _Reconcilable,
    N3: _Reconcilable,
    N4: _Reconcilable,
    N5: _Reconcilable
>:
    _Reconcilable
{
    var value: (N0, N1, N2, N3, N4, N5)

    init(_ n0: N0, _ n1: N1, _ n2: N2, _ n3: N3, _ n4: N4, _ n5: N5) {
        self.value = (n0, n1, n2, n3, n4, n5)
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        value.0.unmount(&context)
        value.1.unmount(&context)
        value.2.unmount(&context)
        value.3.unmount(&context)
        value.4.unmount(&context)
        value.5.unmount(&context)
    }
}
