// SPDX-License-Identifier: Apache-2.0

import Foundation
import Math
import RealNumber

/// Taylor-series expansions of matrix functions.
///
/// The Taylor series of a function `f` around 0 is
/// `f(x) = f(0) + f'(0)·x + f''(0)·x²/2! + f'''(0)·x³/3! + …`
///
/// For `f(x) = eˣ`, all derivatives equal `eˣ` and `f(0) = 1`, giving the famous
///
/// > `eˣ = 1 + x + x²/2! + x³/3! + x⁴/4! + …`
///
/// This extends verbatim to square matrices: replace `x` with a matrix `A` and `1`
/// with the identity matrix `I`:
///
/// > `e^A = I + A + A²/2! + A³/3! + A⁴/4! + …`
///
/// References:
/// - Moler & Van Loan, *Nineteen Dubious Ways to Compute the Exponential of a Matrix,
///   Twenty-Five Years Later*, SIAM Review 45.1 (2003), §2 (the Taylor-series method).
/// - https://en.wikipedia.org/wiki/Matrix_exponential#Taylor_series
public enum Taylor {
    /// Computes `e^A` by summing the Taylor series until convergence (or `maxIterations`).
    ///
    /// **This routine on its own does not handle matrices with large entries well** —
    /// for `‖A‖` large, the partial sums oscillate violently before settling, accumulating
    /// catastrophic floating-point cancellation. The cure is *scaling and squaring*:
    /// reduce `A` to `A / 2^k` (small entries), Taylor-expand that, then square the
    /// result `k` times. See ``Birchall/matrixExponential(_:tolerance:maxIterations:)``
    /// for the production-quality wrapper.
    ///
    /// ### Algorithm
    ///
    /// Compute terms incrementally using the recurrence `Tₖ = Tₖ₋₁ · A / k`:
    ///
    /// 1. Start with `sum = I`, `term = I`.
    /// 2. For `r = 1, 2, …`: set `term ← term · A / r`, then `sum ← sum + term`.
    /// 3. Stop when every entry of `|term / sum|` is below `tolerance`.
    ///
    /// The recurrence avoids recomputing factorials or matrix powers — just one matrix
    /// multiply per term.
    ///
    /// The convergence check uses `abs()` so series with negative-only entries (a
    /// single radioactive compartment, `A = [-λ]`) don't spuriously declare convergence
    /// after one term — a subtle bug present in some textbook implementations.
    public static func exponential(
        of A: Matrix<Double>,
        tolerance: Double = 1e-10,
        maxIterations: Int = 10_000
    ) -> Matrix<Double> {
        let identity = Matrix<Double>.identity(size: A.rows)
        var sum = identity
        var term = identity
        for r in 1 ... maxIterations {
            term = (1 / Double(r)) * (term * A)
            sum += term
            if converged(term: term, sum: sum, tolerance: tolerance) { return sum }
        }
        return sum
    }

    /// True iff every entry of `|term / sum|` is at or below `tolerance`. Entries of
    /// `sum` that are exactly zero are skipped (the ratio is undefined; the series
    /// hasn't yet contributed anything at that position).
    public static func converged(term: Matrix<Double>, sum: Matrix<Double>, tolerance: Double) -> Bool {
        zip(term.storage, sum.storage).allSatisfy { termValue, sumValue in
            sumValue == 0 || abs(termValue / sumValue) <= tolerance
        }
    }
}
