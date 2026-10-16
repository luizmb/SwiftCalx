// SPDX-License-Identifier: Apache-2.0

import Math
import RealNumber

public extension RungeKutta4 {
    /// The matrix one RK4 step applies to a **linear, time-invariant** system `dy/dt = A·y`.
    ///
    /// The four stages of ``rk4(_:)`` with `f(t, y) = A·y` collapse to one product:
    /// `y(t + h) = P·y(t)` with
    ///
    /// ```
    /// P = I + hA + (hA)²/2 + (hA)³/6 + (hA)⁴/24
    /// ```
    ///
    /// RK4's stability polynomial evaluated at `hA` (built here in Horner form). Not an
    /// approximation of RK4: the same method, with the same truncation error and stability
    /// region; only the rounding order differs. It holds only when `A` is constant and the
    /// system has no source term; for `dy/dt = A(t)·y`, `A·y + b(t)` or anything nonlinear, step
    /// with ``trajectory(from:derivative:step:through:)``.
    @inlinable
    static func propagator<Scalar: ℝ>(of A: Matrix<Scalar>, step h: Scalar) -> Matrix<Scalar> {
        let identity = Matrix<Scalar>.identity(size: A.rows)
        return identity + (h * A) * (identity + (h / 2 * A) * (identity + (h / 3 * A) * (identity + (h / 4) * A)))
    }

    /// RK4 on a **linear, time-invariant** system `dy/dt = A·y`, with step `h`, sampled every
    /// `stepsPerSample` steps: `[y₀, y(n·h), y(2n·h), …]`, `count + 1` states.
    ///
    /// ``propagator(of:step:)`` raised to `stepsPerSample` once (``Math/Matrix/raised(to:)``), then
    /// one matrix-vector product per sample (``Math/Matrix/actions(on:count:)``), so the cost
    /// doesn't grow with the number of RK4 steps between samples and the steps in between are never
    /// built. Agrees with stepping ``rk4(_:)`` up to rounding; the iterated product carries the
    /// `n · ε · κ` caveat of `actions(on:count:)`.
    @inlinable
    static func linearTrajectory<Scalar: ℝ>(
        of A: Matrix<Scalar>,
        from initialState: [Scalar],
        step h: Scalar,
        stepsPerSample: Int,
        count: Int
    ) -> [[Scalar]] {
        propagator(of: A, step: h).raised(to: stepsPerSample).actions(on: initialState, count: count)
    }
}
