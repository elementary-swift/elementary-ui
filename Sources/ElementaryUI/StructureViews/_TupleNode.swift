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

public struct _TupleNode2<N0: _Reconcilable & ~Copyable, N1: _Reconcilable & ~Copyable>: ~Copyable, _Reconcilable {
    var n0: N0
    var n1: N1

    init(_ n0: consuming N0, _ n1: consuming N1) {
        self.n0 = n0
        self.n1 = n1
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        n0.unmount(&context)
        n1.unmount(&context)
    }
}

public struct _TupleNode3<N0: _Reconcilable & ~Copyable, N1: _Reconcilable & ~Copyable, N2: _Reconcilable & ~Copyable>: ~Copyable,
    _Reconcilable
{
    var n0: N0
    var n1: N1
    var n2: N2

    init(_ n0: consuming N0, _ n1: consuming N1, _ n2: consuming N2) {
        self.n0 = n0
        self.n1 = n1
        self.n2 = n2
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        n0.unmount(&context)
        n1.unmount(&context)
        n2.unmount(&context)
    }
}

public struct _TupleNode4<
    N0: _Reconcilable & ~Copyable,
    N1: _Reconcilable & ~Copyable,
    N2: _Reconcilable & ~Copyable,
    N3: _Reconcilable & ~Copyable
>: ~Copyable, _Reconcilable {
    var n0: N0
    var n1: N1
    var n2: N2
    var n3: N3

    init(_ n0: consuming N0, _ n1: consuming N1, _ n2: consuming N2, _ n3: consuming N3) {
        self.n0 = n0
        self.n1 = n1
        self.n2 = n2
        self.n3 = n3
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        n0.unmount(&context)
        n1.unmount(&context)
        n2.unmount(&context)
        n3.unmount(&context)
    }
}

public struct _TupleNode5<
    N0: _Reconcilable & ~Copyable,
    N1: _Reconcilable & ~Copyable,
    N2: _Reconcilable & ~Copyable,
    N3: _Reconcilable & ~Copyable,
    N4: _Reconcilable & ~Copyable
>: ~Copyable, _Reconcilable {
    var n0: N0
    var n1: N1
    var n2: N2
    var n3: N3
    var n4: N4

    init(_ n0: consuming N0, _ n1: consuming N1, _ n2: consuming N2, _ n3: consuming N3, _ n4: consuming N4) {
        self.n0 = n0
        self.n1 = n1
        self.n2 = n2
        self.n3 = n3
        self.n4 = n4
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        n0.unmount(&context)
        n1.unmount(&context)
        n2.unmount(&context)
        n3.unmount(&context)
        n4.unmount(&context)
    }
}

public struct _TupleNode6<
    N0: _Reconcilable & ~Copyable,
    N1: _Reconcilable & ~Copyable,
    N2: _Reconcilable & ~Copyable,
    N3: _Reconcilable & ~Copyable,
    N4: _Reconcilable & ~Copyable,
    N5: _Reconcilable & ~Copyable
>:
    ~Copyable, _Reconcilable
{
    var n0: N0
    var n1: N1
    var n2: N2
    var n3: N3
    var n4: N4
    var n5: N5

    init(_ n0: consuming N0, _ n1: consuming N1, _ n2: consuming N2, _ n3: consuming N3, _ n4: consuming N4, _ n5: consuming N5) {
        self.n0 = n0
        self.n1 = n1
        self.n2 = n2
        self.n3 = n3
        self.n4 = n4
        self.n5 = n5
    }

    public consuming func unmount(_ context: inout _CommitContext) {
        n0.unmount(&context)
        n1.unmount(&context)
        n2.unmount(&context)
        n3.unmount(&context)
        n4.unmount(&context)
        n5.unmount(&context)
    }
}
