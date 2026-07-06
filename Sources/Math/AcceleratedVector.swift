// SPDX-License-Identifier: Apache-2.0

import CoreFP
import RealNumber

/// A first-class, hardware-acceleration-friendly numeric vector of `Double`.
///
/// `AcceleratedVector` is the opt-in fast state type for ``RungeKutta4``, ``RungeKutta45``,
/// and any other generic-over-``VectorState`` solver. Wrap your `[Double]` once
/// at the entry point and every per-stage `+` / `*` along the integration
/// trajectory routes through hand-tuned BLAS / vDSP kernels on Apple
/// platforms via the protocol witness — without runtime type checks or
/// specialised overloads on the solver itself.
///
/// ## Why a wrapper around `[Double]`?
///
/// `Array<Double>` already conforms to ``VectorState``, but Swift selects the
/// protocol witness for `+` and scalar `*` at the conformance site — which
/// uses the generic, scalar `zip(...).map(+)` implementation. There's no way
/// to "specialise" that witness for `[Double]` without breaking the protocol
/// rules. `AcceleratedVector` sidesteps the problem by being its own concrete type
/// whose own witness for `+` and `*` is the optimised vDSP path. Generic
/// solver code dispatches naturally through the witness; no specialisation
/// overloads, no runtime checks, no `.+` operator gymnastics.
///
/// ## When `AcceleratedVector` doesn't matter
///
/// On non-Apple builds (Linux / WASM) and on Apple builds with the
/// `-D SWIFTCALX_NO_ACCELERATE` flag, `AcceleratedVector`'s `+` / `*` fall back to the
/// same scalar Swift implementation that `[Double]` uses. No win; no loss.
/// The performance edge is specifically vDSP.
///
/// ## Migration cost
///
/// One line at the entry point and (importantly) one line in the derivative
/// function, both zero-allocation:
///
/// ```swift
/// // Before — [Double] state, scalar per-stage ops
/// let trajectory = RungeKutta45.trajectory(
///     at: outputTimes,
///     from: [1.0, 0.0],
///     derivative: { _, y in A.apply(to: y) }
/// )
///
/// // After — AcceleratedVector state, vDSP per-stage ops
/// let trajectory = RungeKutta45.trajectory(
///     at: outputTimes,
///     from: [1.0, 0.0].asAcceleratedVector,
///     derivative: { _, y in A.apply(to: y) }   // returns AcceleratedVector via the bridge overload
/// )
/// ```
///
/// `AcceleratedVector` is a thin struct around `[Double]` — `AcceleratedVector(myArray)` and
/// `myArray.asAcceleratedVector` share the array's underlying COW buffer, no copy.
public struct AcceleratedVector: Sendable {
    /// The underlying `[Double]` buffer. Same shape and indexing as a flat
    /// row of `Matrix`; safe to hand back out for interop.
    public let storage: [Double]

    public init(_ storage: [Double]) {
        self.storage = storage
    }

    /// Convenience initialiser for variadic Double values: `AcceleratedVector(1.0, 2.0, 3.0)`.
    public init(_ elements: Double...) {
        storage = elements
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }
}

// MARK: - Conformances

extension AcceleratedVector: Equatable {}
extension AcceleratedVector: Hashable {}

// MARK: - Monoid (under concatenation, mirrors `Array`'s direct conformance)

//
// Distinct from elementwise addition (`+`, which lives on the `VectorState`
// conformance). `combine` joins two vectors end-to-end; `identity` is the
// empty vector. Fold a sequence of vectors into one with `mconcat`.

extension AcceleratedVector: Semigroup {
    public static func combine(_ lhs: AcceleratedVector, _ rhs: AcceleratedVector) -> AcceleratedVector {
        // NB: use `append(contentsOf:)`, not `lhs.storage + rhs.storage` —
        // `Array: VectorState where Element: ℝ` (VectorState.swift) defines
        // `+` for `[Double]` to be *elementwise addition*, which silently
        // wins over stdlib's `RangeReplaceableCollection.+` concatenation.
        var concatenated = lhs.storage
        concatenated.append(contentsOf: rhs.storage)
        return AcceleratedVector(concatenated)
    }
}

extension AcceleratedVector: Monoid {
    public static var identity: AcceleratedVector { AcceleratedVector([]) }
}

extension AcceleratedVector: CustomStringConvertible {
    public var description: String { "AcceleratedVector(\(storage))" }
}

extension AcceleratedVector: CustomDebugStringConvertible {
    public var debugDescription: String { "AcceleratedVector(\(storage.debugDescription))" }
}

// MARK: - Collection support (so for-each, map, filter, reduce, indexing all work)

extension AcceleratedVector: RandomAccessCollection {
    public typealias Element = Double
    public typealias Index = Int

    public var startIndex: Int { storage.startIndex }
    public var endIndex: Int { storage.endIndex }
    public func index(after i: Int) -> Int { storage.index(after: i) }
    public func index(before i: Int) -> Int { storage.index(before: i) }
    public subscript(position: Int) -> Double { storage[position] }
}

// MARK: - Type-preserving map

public extension AcceleratedVector {
    /// Element-wise transformation that stays in `AcceleratedVector`-land. Use when you
    /// want a `AcceleratedVector` back; the inherited Collection `map` returns `[T]`
    /// (and naturally `[Double]` when `T == Double`).
    func mapAccelerated(_ transform: (Double) -> Double) -> AcceleratedVector {
        AcceleratedVector(storage.map(transform))
    }
}

// MARK: - Array bridge

public extension [Double] {
    /// Wrap `self` as a `AcceleratedVector` without copying. Same COW buffer.
    var asAcceleratedVector: AcceleratedVector { AcceleratedVector(self) }
}
