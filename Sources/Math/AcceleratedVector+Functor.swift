// SPDX-License-Identifier: Apache-2.0

import RealNumber

public extension AcceleratedVector {
    /// Pure, non-throwing element transformation returning `[T]`. Shadows
    /// `Sequence.map`'s `rethrows` form so the `AcceleratedVector` surface
    /// is closed under purity — call sites can't smuggle in `throws` closures
    /// (use `Result` / `DeferredTask` for error handling).
    ///
    ///     map :: AcceleratedVector -> (Double -> b) -> [b]
    func map<T>(_ transform: @Sendable (Double) -> T) -> [T] {
        storage.map(transform)
    }

    /// Curried, generic version of `map`. Mirrors `Array.fmap` from FP's
    /// `CoreFP`.
    ///
    ///     fmap :: (a -> b) -> f a -> f b
    static func fmap<A1>(
        _ fn: @escaping @Sendable (Double) -> A1
    ) -> @Sendable (AcceleratedVector) -> [A1] {
        { vector in vector.storage.map(fn) }
    }

    /// Type-preserving curried `fmap` for the common `(Double) -> Double`
    /// case — keeps the result inside `AcceleratedVector`-land so subsequent
    /// `+` / `*` stay on the vDSP path.
    static func fmap(
        _ fn: @escaping @Sendable (Double) -> Double
    ) -> @Sendable (AcceleratedVector) -> AcceleratedVector {
        { vector in vector.mapAccelerated(fn) }
    }
}
