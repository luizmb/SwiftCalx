// SPDX-License-Identifier: Apache-2.0

import Math
import RealNumber

/// Simpson's-rule weighted combination of four substep slopes:
/// `(k₁ + 2·k₂ + 2·k₃ + k₄) / 6`.
///
/// This is the **canonical RK4 weighting**. It coincides with Simpson's 1/3 rule for
/// numerical quadrature applied to the four slope estimates: weights `(1, 4, 1)/6`
/// across `(start, midpoint, end)`, where the middle slope is replaced by the average
/// of two midpoint estimates `(k₂ + k₃)/2`, giving the familiar `(1, 2, 2, 1)/6` pattern.
///
/// ### Where this comes from
///
/// Simpson's 1/3 rule for `∫ₐᵇ f(x) dx` approximates the integral by fitting a parabola
/// through `f(a)`, `f((a+b)/2)`, `f(b)` and integrating it exactly:
///
/// > `∫ₐᵇ f(x) dx ≈ ((b - a) / 6) · (f(a) + 4·f((a+b)/2) + f(b))`
///
/// In RK4 the four slopes (`k₁` start, `k₂` & `k₃` midpoint, `k₄` end) play the role of
/// `f(a)`, `f((a+b)/2)` (estimated twice for stability), and `f(b)`. Substituting:
///
/// > `(k₁ + 4·((k₂ + k₃)/2) + k₄) / 6  =  (k₁ + 2·k₂ + 2·k₃ + k₄) / 6`
///
/// The "4" of Simpson's rule becomes "2·k₂ + 2·k₃" — same constant, split across two
/// midpoint estimates. This is why RK4 is fourth-order accurate: it's effectively
/// applying Simpson's rule to the velocity field over each step.
///
/// References:
/// - Butcher, *Numerical Methods for Ordinary Differential Equations*, §2.4.
/// - Atkinson, *An Introduction to Numerical Analysis*, §5.3 (Simpson's rule derivation).
/// - https://en.wikipedia.org/wiki/Runge–Kutta_methods#The_Runge–Kutta_method
///
/// ### Generic over `VectorState`
///
/// Works equally for scalar `T: ℝ` (because every concrete real number conforms to
/// ``VectorState`` with `Scalar == Self`) and for vector states like `[Double]`. The
/// scalar and vector RK4 solvers in ``RungeKutta4`` both delegate to this function —
/// the algorithmic concept is identical, only the type of `k` differs.
public enum SimpsonWeightedAverage {
    /// Returns `(v₁ + 2·v₂ + 2·v₃ + v₄) / 6`.
    ///
    /// Positional rather than labelled so the function reads symmetrically with the
    /// math notation. In RK4 the four arguments are the slope-times-step contributions
    /// `Δy₁ … Δy₄` (or `k₁ … k₄` if you prefer slope-only and let the caller scale).
    public static func calculate<State: VectorState>(
        _ v1: State, _ v2: State, _ v3: State, _ v4: State
    ) -> State {
        let two: State.Scalar = 2
        let six: State.Scalar = 6
        return (1 / six) * (v1 + two * v2 + two * v3 + v4)
    }
}
