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
            AcceleratedVector(cartesianProduct(lhs.storage, rhs.storage, fn))
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
        AcceleratedVector(cartesianProduct(functions, values.storage) { f, value in f(value) })
    }

    /// Cartesian product, keeping right values. Mirrors `Array.seqRight`.
    ///
    ///     seqRight :: AcceleratedVector -> AcceleratedVector -> AcceleratedVector
    func seqRight(_ rhs: AcceleratedVector) -> AcceleratedVector {
        AcceleratedVector(cartesianProduct(storage, rhs.storage) { _, b in b })
    }

    /// Cartesian product, keeping left values. Mirrors `Array.seqLeft`.
    ///
    ///     seqLeft :: AcceleratedVector -> AcceleratedVector -> AcceleratedVector
    func seqLeft(_ rhs: AcceleratedVector) -> AcceleratedVector {
        AcceleratedVector(cartesianProduct(storage, rhs.storage) { a, _ in a })
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

/// `[combine(a, b) for a in lhs for b in rhs]`, built in one allocation (a `flatMap` over a
/// `map` would build one inner array per element of `lhs`).
@inlinable
func cartesianProduct<A, B, T>(_ lhs: [A], _ rhs: [B], _ combine: (A, B) -> T) -> [T] {
    var result: [T] = []
    result.reserveCapacity(lhs.count * rhs.count)
    for a in lhs {
        for b in rhs {
            result.append(combine(a, b))
        }
    }
    return result
}
