// SPDX-License-Identifier: Apache-2.0

import CoreFP
import RealNumber

public extension Matrix {
    /// `Matrix` under elementwise addition as a **semigroup** (not a monoid).
    ///
    /// Naming matches FP's ``NumericMonoid/Sum`` — `Sum` is what we'd reach for
    /// in any other "elementwise addition under a wrapper" context. `Semigroup`
    /// rather than `Monoid` because the identity (the zero matrix) depends on
    /// the matrix shape — `Monoid.identity` is a `static var Self` that has no
    /// way to pick `rows` or `columns`. ``sconcat(_:_:)`` handles non-empty
    /// folds without needing an identity:
    ///
    /// ```swift
    /// let total = sconcat(Matrix.Sum(matrices[0]), matrices.dropFirst().map(Matrix.Sum.init))
    /// total.rawValue   // matrix sum
    /// ```
    ///
    /// All operands in a fold must share the same shape — `combine` calls the
    /// shape-checked elementwise `+` underneath.
    struct Sum: Semigroup, RawRepresentable {
        public let rawValue: Matrix<Scalar>

        public init(_ rawValue: Matrix<Scalar>) {
            self.rawValue = rawValue
        }

        public init?(rawValue: Matrix<Scalar>) {
            self.init(rawValue)
        }

        public static func combine(_ lhs: Sum, _ rhs: Sum) -> Sum {
            Sum(lhs.rawValue + rhs.rawValue)
        }
    }

    /// `Matrix` under matrix multiplication as a **semigroup** (not a monoid).
    ///
    /// Naming matches FP's ``NumericMonoid/Product``. `Semigroup` rather than
    /// `Monoid` because the multiplicative identity is the `n × n` identity
    /// matrix `Iₙ` — again, `static var identity` can't pick a size.
    ///
    /// This is the algebraic structure behind Birchall's matrix-exponential
    /// semigroup: `exp((s + t) · A) = exp(s · A) · exp(t · A)`. For the
    /// *iterated-action* form used in practice (apply `B = exp(Δt · A)` to a
    /// starting vector `n` times), see ``Matrix/actions(on:count:)`` — it
    /// avoids the O(n³) per step cost of multiplying matrix powers and just
    /// does O(n²) per step mat-vec.
    struct Product: Semigroup, RawRepresentable {
        public let rawValue: Matrix<Scalar>

        public init(_ rawValue: Matrix<Scalar>) {
            self.rawValue = rawValue
        }

        public init?(rawValue: Matrix<Scalar>) {
            self.init(rawValue)
        }

        public static func combine(_ lhs: Product, _ rhs: Product) -> Product {
            Product(lhs.rawValue * rhs.rawValue)
        }
    }
}
