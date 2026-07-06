// SPDX-License-Identifier: Apache-2.0

import RealNumber

public extension Matrix {
    /// Iteratively applies this matrix `count` times to `initial`, collecting every
    /// intermediate state.
    ///
    /// Returns the trajectory `[initial, M·initial, M²·initial, …, Mᶜᵒᵘⁿᵗ·initial]`
    /// — `count + 1` entries in total.
    ///
    /// ## Why this exists
    ///
    /// Computing `Mⁿ · initial` directly via repeated matrix multiplication is
    /// `O(n · rows³)`. Computing it via repeated matrix-*vector* application is
    /// `O(n · rows · cols)` — typically an order of magnitude cheaper. Whenever you
    /// only ever apply the powers of `M` to a fixed starting vector, mat-vec wins.
    ///
    /// This is the practical mechanic behind Birchall's matrix-exponential
    /// semigroup optimisation: pre-compute `B = exp(Δt · A)` once, then walk the
    /// linear-ODE trajectory with `actions(on: y₀, count: n)`. The full trajectory
    /// costs one expensive matrix exponential plus `n` cheap mat-vecs, instead of
    /// `n + 1` independent matrix exponentials.
    ///
    /// ## Numerical caveat
    ///
    /// Iterating `M·x` accumulates floating-point error roughly as `n · ε · κ`,
    /// where `ε` is machine epsilon and `κ` is the condition number of `M`. For
    /// well-conditioned `M` and modest `n` the drift is invisible; for stiff
    /// systems (large `κ`) it can dominate. Compare against fresh `Mⁿ · initial`
    /// to spot when this matters.
    func actions(on initial: [Scalar], count: Int) -> [[Scalar]] {
        guard count >= 0 else { return [initial] }
        var x = initial
        var result: [[Scalar]] = [initial]
        result.reserveCapacity(count + 1)
        for _ in 0 ..< count {
            x = apply(to: x)
            result.append(x)
        }
        return result
    }
}
