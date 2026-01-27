extension Float: AnimatableVectorConvertible {
    @inlinable
    public init(_animatableVector animatableVector: AnimatableVector) {
        guard case .d1(let value) = animatableVector.storage else {
            fatalError("Unsupported animatable vector in Float initializer")
        }
        self = value
    }

    @inlinable
    public var animatableVector: AnimatableVector {
        .init(.d1(self))
    }
}
extension SIMD2<Float>: AnimatableVectorConvertible {
    @inlinable
    public init(_animatableVector animatableVector: AnimatableVector) {
        guard case .d2(let value) = animatableVector.storage else {
            fatalError("Unsupported animatable vector in SIMD2<Float> initializer")
        }
        self = value
    }

    @inlinable
    public var animatableVector: AnimatableVector {
        .init(.d2(self))
    }
}

extension SIMD4<Float>: AnimatableVectorConvertible {
    @inlinable
    public init(_animatableVector animatableVector: AnimatableVector) {
        guard case .d4(let value) = animatableVector.storage else {
            fatalError("Unsupported animatable vector in SIMD4<Float> initializer")
        }
        self = value
    }

    @inlinable
    public var animatableVector: AnimatableVector {
        .init(.d4(self))
    }
}

extension SIMD8<Float>: AnimatableVectorConvertible {
    @inlinable
    public init(_animatableVector animatableVector: AnimatableVector) {
        guard case .d8(let value) = animatableVector.storage else {
            fatalError("Unsupported animatable vector in SIMD8<Float> initializer")
        }
        self = value
    }

    @inlinable
    public var animatableVector: AnimatableVector {
        .init(.d8(self))
    }
}

// MARK: - SIMD<Double> convenience methods (using Float under the hood)

extension Double: AnimatableVectorConvertible {
    @inlinable
    public init(_animatableVector animatableVector: AnimatableVector) {
        self = Double(Float(_animatableVector: animatableVector))
    }

    @inlinable
    public var animatableVector: AnimatableVector {
        Float(self).animatableVector
    }
}

extension SIMD2<Double> {
    @inlinable
    public init(_animatableVector animatableVector: AnimatableVector) {
        let float = SIMD2<Float>(_animatableVector: animatableVector)
        self = SIMD2<Double>(float)
    }

    @inlinable
    public var animatableVector: AnimatableVector {
        SIMD2<Float>(self).animatableVector
    }
}

extension SIMD4<Double> {
    @inlinable
    public init(_animatableVector animatableVector: AnimatableVector) {
        let float = SIMD4<Float>(_animatableVector: animatableVector)
        self = SIMD4<Double>(float)
    }

    @inlinable
    public var animatableVector: AnimatableVector {
        SIMD4<Float>(self).animatableVector
    }
}

extension SIMD8<Double> {
    @inlinable
    public init(_animatableVector animatableVector: AnimatableVector) {
        let float = SIMD8<Float>(_animatableVector: animatableVector)
        self = SIMD8<Double>(float)
    }

    @inlinable
    public var animatableVector: AnimatableVector {
        SIMD8<Float>(self).animatableVector
    }
}
