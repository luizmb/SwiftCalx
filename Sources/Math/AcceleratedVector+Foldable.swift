import CoreFP

extension AcceleratedVector {
    /// Left-associative fold using an accumulator. Mirrors `Array.foldLeft`.
    ///
    ///     foldLeft :: b -> (b -> a -> b) -> AcceleratedVector -> b
    public static func foldLeft<B: Sendable>(
        _ initial: B,
        _ f: @escaping @Sendable (B, Double) -> B
    ) -> @Sendable (AcceleratedVector) -> B {
        { vector in vector.storage.reduce(initial, f) }
    }

    /// Right-associative fold using an accumulator. Mirrors `Array.foldRight`.
    ///
    ///     foldRight :: (a -> b -> b) -> b -> AcceleratedVector -> b
    public static func foldRight<B: Sendable>(
        _ f: @escaping @Sendable (Double, B) -> B,
        _ initial: B
    ) -> @Sendable (AcceleratedVector) -> B {
        { vector in
            vector.storage.reversed().reduce(initial) { acc, elem in f(elem, acc) }
        }
    }

    /// Map each element to a Monoid, then combine. Mirrors `Array.foldMap`.
    ///
    ///     foldMap :: Monoid m => (a -> m) -> AcceleratedVector -> m
    public static func foldMap<M: Monoid>(
        _ f: @escaping @Sendable (Double) -> M
    ) -> @Sendable (AcceleratedVector) -> M {
        // Qualify with `M.` — FP's `Monoid.mconcat` static method otherwise shadows the free
        // `mconcat<M>` inside this `AcceleratedVector: Monoid` extension (it resolves to `Self`,
        // giving "cannot convert '[M]' to '[AcceleratedVector]'"). Surfaced by FP 1.13.
        { vector in M.mconcat(vector.storage.map(f)) }
    }
}
