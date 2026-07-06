// SPDX-License-Identifier: Apache-2.0

import RealNumber

public extension AcceleratedVector {
    /// 2-ary Cartesian product of two vectors — every pair `(a, b)` with `a`
    /// from `first` and `b` from `second`, ordered outer-then-inner.
    /// Returns `[(Double, Double)]` because the result element type isn't
    /// `Double`; for the elementwise-style "pairs of indices match", use
    /// `Swift.zip(first.storage, second.storage)` or
    /// ``AcceleratedVector/liftA2(_:)``-with-tuple.
    ///
    /// Mirrors `Array.cartesian(_:_:)` from FP's `CoreFP/Array+Cartesian`.
    static func cartesian(_ first: AcceleratedVector, _ second: AcceleratedVector) -> [(Double, Double)] {
        first.storage.flatMap { a in second.storage.map { b in (a, b) } }
    }

    /// 3-ary Cartesian product. Result length is `n × m × p`.
    /// Mirrors `Array.cartesian(_:_:_:)`.
    static func cartesian(
        _ first: AcceleratedVector,
        _ second: AcceleratedVector,
        _ third: AcceleratedVector
    ) -> [(Double, Double, Double)] {
        first.storage.flatMap { a in
            second.storage.flatMap { b in
                third.storage.map { c in (a, b, c) }
            }
        }
    }
}
