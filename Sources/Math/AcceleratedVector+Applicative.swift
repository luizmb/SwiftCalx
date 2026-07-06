// SPDX-License-Identifier: Apache-2.0

import RealNumber

public extension AcceleratedVector {
    /// Lift a binary `(Double, Double) -> Double` into an operation on
    /// `AcceleratedVector`s by Cartesian product. Mirrors `Array.liftA2` from FP's
    /// `CoreFP` (which uses `flatMap` + `map` for the non-determinism
    /// monad's Applicative).
    ///
    ///     liftA2 :: (a -> b -> c) -> [a] -> [b] -> [c]
    ///
    /// Note the Cartesian semantics: result length is `lhs.count * rhs.count`,
    /// not elementwise. For elementwise arithmetic prefer ``AcceleratedVector/+(_:_:)``
    /// and friends.
    static func liftA2(
        _ fn: @escaping @Sendable (Double, Double) -> Double
    ) -> @Sendable (AcceleratedVector, AcceleratedVector) -> AcceleratedVector {
        { lhs, rhs in
            AcceleratedVector(lhs.storage.flatMap { a in
                rhs.storage.map { b in fn(a, b) }
            })
        }
    }

    /// Applicative apply — applies a vector of functions to a vector of
    /// values via Cartesian product. Mirrors `Array.apply` from FP's
    /// `CoreFP`.
    ///
    ///     (<*>) :: [a -> b] -> [a] -> [b]
    static func apply(
        _ functions: [@Sendable (Double) -> Double],
        _ values: AcceleratedVector
    ) -> AcceleratedVector {
        AcceleratedVector(functions.flatMap { f in values.storage.map(f) })
    }

    /// Cartesian product, keeping right values. Mirrors `Array.seqRight`.
    ///
    ///     seqRight :: AcceleratedVector -> AcceleratedVector -> AcceleratedVector
    func seqRight(_ rhs: AcceleratedVector) -> AcceleratedVector {
        AcceleratedVector(storage.flatMap { _ in rhs.storage })
    }

    /// Cartesian product, keeping left values. Mirrors `Array.seqLeft`.
    ///
    ///     seqLeft :: AcceleratedVector -> AcceleratedVector -> AcceleratedVector
    func seqLeft(_ rhs: AcceleratedVector) -> AcceleratedVector {
        AcceleratedVector(storage.flatMap { a in rhs.storage.map { _ in a } })
    }

    /// Index-aligned zip — pairs elements at matching positions, stopping at
    /// the shorter of the two. Returns `[(Double, Double)]` because the
    /// result element type isn't `Double` (no AcceleratedVector-of-tuples). Mirrors
    /// `Swift.zip` exposed in array form.
    ///
    /// For the all-combinations form, see ``cartesian(_:_:)``.
    static func zip(_ lhs: AcceleratedVector, _ rhs: AcceleratedVector) -> [(Double, Double)] {
        Array(Swift.zip(lhs.storage, rhs.storage))
    }
}
