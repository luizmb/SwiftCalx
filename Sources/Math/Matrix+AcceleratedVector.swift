// SPDX-License-Identifier: Apache-2.0

import RealNumber

public extension Matrix where Scalar == Double {
    /// `Matrix · AcceleratedVector` — same compute as ``apply(to:)-9wzs`` for `[Double]`,
    /// but takes and returns ``AcceleratedVector`` so consumers in `AcceleratedVector`-land
    /// (typically the derivative function passed to a generic-over-VectorState
    /// solver) don't have to round-trip through `[Double]` explicitly.
    ///
    /// Zero overhead vs the `[Double]` overload — the `AcceleratedVector` wrapper is a
    /// thin struct around the COW backing array; `vector.storage` shares the
    /// buffer, and `AcceleratedVector(...)` wraps the result without copying.
    func apply(to vector: AcceleratedVector) -> AcceleratedVector {
        AcceleratedVector(apply(to: vector.storage))
    }
}
