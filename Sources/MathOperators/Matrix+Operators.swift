// SPDX-License-Identifier: Apache-2.0

import Math
import RealNumber

/// Mathematical dot (`⋅`, U+00B7) for matrix products. Reads naturally as it would on
/// paper: `A ⋅ B` for matrix–matrix, `α ⋅ A` for scalar–matrix, `A ⋅ v` for matrix–vector.
///
/// All three overloads delegate to the named methods on ``Math/Matrix`` (`*` and
/// `apply(to:)`). If you'd rather type `*` and `.apply(to:)`, they remain available;
/// `⋅` is a convenience for the mathematically-fluent reader.
infix operator ⋅: MultiplicationPrecedence

/// Matrix–matrix multiplication. Equivalent to `lhs * rhs`. See
/// ``Math/Matrix/*(_:_:)-(Matrix,Matrix)``.
public func ⋅ <Scalar: ℝ>(lhs: Matrix<Scalar>, rhs: Matrix<Scalar>) -> Matrix<Scalar> {
    lhs * rhs
}

/// Scalar–matrix multiplication. Equivalent to `scalar * matrix`.
public func ⋅ <Scalar: ℝ>(scalar: Scalar, matrix: Matrix<Scalar>) -> Matrix<Scalar> {
    scalar * matrix
}

/// Matrix–vector application. Equivalent to `matrix.apply(to: vector)`.
public func ⋅ <Scalar: ℝ>(matrix: Matrix<Scalar>, vector: [Scalar]) -> [Scalar] {
    matrix.apply(to: vector)
}
