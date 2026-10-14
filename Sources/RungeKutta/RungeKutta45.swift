// SPDX-License-Identifier: Apache-2.0

import Foundation
import Math
import RealNumber

/// **Dormand–Prince 5(4)** embedded Runge–Kutta method — the standard adaptive
/// explicit RK pair used by SciPy's `RK45`, MATLAB's `ode45`, and most modern
/// non-stiff ODE solvers.
///
/// The method takes seven slope samples per step (`k1…k7`) and computes **two**
/// estimates from the same samples: a 5th-order accurate one and a 4th-order
/// accurate one. The difference between them estimates the local truncation
/// error; the step size is grown or shrunk to keep that error near the caller's
/// `tolerance`. Steps whose error exceeds the tolerance are rejected and
/// retried with a smaller step; steps whose error is well below it allow the
/// next step to grow.
///
/// **FSAL** (First-Same-As-Last): `k7` of an accepted step equals `k1` of the
/// next step, so we save one function evaluation per accepted step — six
/// evaluations on average, not seven.
///
/// ## When to use this
///
/// - **Use it** for smooth, non-stiff ODEs where you want automatic step
///   selection and don't want to hand-tune `RungeKutta4`'s fixed step.
/// - **Don't use it** for stiff systems (eigenvalues of the Jacobian differing
///   by many orders of magnitude — common in chemical kinetics, biokinetics
///   with fast / slow compartments). Explicit RK at any order needs tiny steps
///   for *stability*, not accuracy, on stiff problems. For those, an implicit
///   method (BDF / Gear, Radau-IIA, Rosenbrock) is the right tool.
/// - **Linear constant-coefficient** systems (e.g. ICRP biokinetic models)
///   have an analytic solution `y(t) = exp(A·t)·y₀` via the matrix exponential —
///   use ``Calculus/Taylor/exponential(of:tolerance:maxIterations:)`` or a
///   scaling-and-squaring variant. RK45 is overkill for those.
///
/// ## References
///
/// - Dormand, J.R. & Prince, P.J. (1980). *A family of embedded Runge-Kutta
///   formulae*. Journal of Computational and Applied Mathematics 6(1): 19–26.
/// - Hairer, Nørsett & Wanner, *Solving Ordinary Differential Equations I:
///   Nonstiff Problems* (Springer, 2nd ed., 1993), §II.5.
/// - https://en.wikipedia.org/wiki/Dormand–Prince_method
public enum RungeKutta45 {}

// MARK: - Dormand–Prince coefficients

//
// Butcher tableau, with the embedded 4th-order weights below the line:
//
//   c | A
//   ----
//     | b   ← 5th order
//     | b*  ← 4th order
//
// All coefficients are exact rationals from the Dormand–Prince 1980 paper.

extension RungeKutta45 {
    /// Time offsets at which the seven stages are evaluated, relative to `t`.
    /// `c1 = 0` (the start of the step) is implicit and omitted.
    @usableFromInline
    enum C {
        @inlinable static var c2: Double { 1.0 / 5.0 }
        @inlinable static var c3: Double { 3.0 / 10.0 }
        @inlinable static var c4: Double { 4.0 / 5.0 }
        @inlinable static var c5: Double { 8.0 / 9.0 }
        @inlinable static var c6: Double { 1.0 }
        @inlinable static var c7: Double { 1.0 }
    }

    /// Inter-stage weights — the `a[i][j]` from the Butcher tableau, naming the
    /// fields directly so the recurrence reads like the textbook.
    @usableFromInline
    enum A {
        @inlinable static var a21: Double { 1.0 / 5.0 }

        @inlinable static var a31: Double { 3.0 / 40.0 }
        @inlinable static var a32: Double { 9.0 / 40.0 }

        @inlinable static var a41: Double { 44.0 / 45.0 }
        @inlinable static var a42: Double { -56.0 / 15.0 }
        @inlinable static var a43: Double { 32.0 / 9.0 }

        @inlinable static var a51: Double { 19_372.0 / 6_561.0 }
        @inlinable static var a52: Double { -25_360.0 / 2_187.0 }
        @inlinable static var a53: Double { 64_448.0 / 6_561.0 }
        @inlinable static var a54: Double { -212.0 / 729.0 }

        @inlinable static var a61: Double { 9_017.0 / 3_168.0 }
        @inlinable static var a62: Double { -355.0 / 33.0 }
        @inlinable static var a63: Double { 46_732.0 / 5_247.0 }
        @inlinable static var a64: Double { 49.0 / 176.0 }
        @inlinable static var a65: Double { -5_103.0 / 18_656.0 }

        // a7i double as the b5 weights (FSAL property).
        // a72 = 0 — canonical-tableau zero, elided from code.
        @inlinable static var a71: Double { 35.0 / 384.0 }
        @inlinable static var a73: Double { 500.0 / 1_113.0 }
        @inlinable static var a74: Double { 125.0 / 192.0 }
        @inlinable static var a75: Double { -2_187.0 / 6_784.0 }
        @inlinable static var a76: Double { 11.0 / 84.0 }
    }

    /// 5th-order solution weights. Equal to `a7*` (FSAL).
    /// b2 = b7 = 0 — canonical-tableau zeroes, elided from code.
    @usableFromInline
    enum B5 {
        @inlinable static var b1: Double { A.a71 }
        @inlinable static var b3: Double { A.a73 }
        @inlinable static var b4: Double { A.a74 }
        @inlinable static var b5: Double { A.a75 }
        @inlinable static var b6: Double { A.a76 }
    }

    /// 4th-order embedded weights — used to estimate the local truncation error.
    /// b2 = 0 — canonical-tableau zero, elided from code.
    @usableFromInline
    enum B4 {
        @inlinable static var b1: Double { 5_179.0 / 57_600.0 }
        @inlinable static var b3: Double { 7_571.0 / 16_695.0 }
        @inlinable static var b4: Double { 393.0 / 640.0 }
        @inlinable static var b5: Double { -92_097.0 / 339_200.0 }
        @inlinable static var b6: Double { 187.0 / 2_100.0 }
        @inlinable static var b7: Double { 1.0 / 40.0 }
    }
}

// MARK: - Step

public extension RungeKutta45 {
    /// One Dormand–Prince step. Returns the accepted-or-not pair of estimates
    /// plus the error-weighted norm; callers (the trajectory driver) decide
    /// whether to accept and how to size the next step.
    ///
    /// Generic over any ``NormedVectorState`` whose scalar is `Double` — that
    /// covers `[Double]` (the typical multi-compartment shape) and `Double`
    /// itself (the scalar case).
    struct Step<State: NormedVectorState> where State.Scalar == Double {
        /// 5th-order accurate estimate of `y(t + h)`.
        public let y5: State
        /// 4th-order embedded estimate of `y(t + h)`.
        public let y4: State
        /// `f(t + h, y5)` — i.e. the last stage, ready to be reused as `k1` of
        /// the next step if this one is accepted (FSAL).
        public let kLast: State
        /// Infinity-norm of `(y5 − y4)`. Compared against the caller's tolerance.
        public let errorNorm: Double

        @inlinable
        init(y5: State, y4: State, kLast: State, errorNorm: Double) {
            self.y5 = y5
            self.y4 = y4
            self.kLast = kLast
            self.errorNorm = errorNorm
        }
    }

    /// Compute one Dormand–Prince step from `(t, y)` of size `h`, given the
    /// initial slope `k1 = f(t, y)`. Returns the embedded pair + error norm
    /// without judging acceptability — see ``trajectory(from:derivative:startingAt:through:tolerance:initialStep:minStep:maxStep:maxIterations:)``
    /// for the adaptive driver that does the accept/reject + step-size logic.
    @inlinable
    static func step<State: NormedVectorState>(
        from t: Double,
        y: State,
        k1: State,
        size h: Double,
        derivative f: @Sendable (Double, State) -> State
    ) -> Step<State> where State.Scalar == Double {
        // Each stage's input state is `y + Σ (h·aᵢⱼ)·kⱼ`, accumulated left to right into
        // one fresh state with `add(_:scaledBy:)`: the same sums as writing it with `+` and
        // `*`, without a new state for every term.
        func stage(_ terms: (State, Double)...) -> State {
            var sum = y
            for (k, a) in terms {
                sum.add(k, scaledBy: h * a)
            }
            return sum
        }

        let k2 = f(t + C.c2 * h, stage((k1, A.a21)))
        let k3 = f(t + C.c3 * h, stage((k1, A.a31), (k2, A.a32)))
        let k4 = f(t + C.c4 * h, stage((k1, A.a41), (k2, A.a42), (k3, A.a43)))
        let k5 = f(t + C.c5 * h, stage((k1, A.a51), (k2, A.a52), (k3, A.a53), (k4, A.a54)))
        let k6 = f(t + C.c6 * h, stage((k1, A.a61), (k2, A.a62), (k3, A.a63), (k4, A.a64), (k5, A.a65)))

        // 5th-order solution. B5.b2 and B5.b7 are zero, so those terms drop out.
        let y5 = stage((k1, B5.b1), (k3, B5.b3), (k4, B5.b4), (k5, B5.b5), (k6, B5.b6))

        // k7 = f(t + h, y5) — the FSAL stage. Used in the 4th-order estimate
        // *and* reused as next step's k1 when this step is accepted.
        let k7 = f(t + C.c7 * h, y5)

        // 4th-order embedded estimate. B4.b2 is zero.
        let y4 = stage((k1, B4.b1), (k3, B4.b3), (k4, B4.b4), (k5, B4.b5), (k6, B4.b6), (k7, B4.b7))

        // Error = ||y5 − y4|| in the infinity norm. We compute `y5 − y4` as
        // `y5 + (−1)·y4` since VectorState only requires `+` and scalar `*`.
        var diff = y5
        diff.add(y4, scaledBy: -1.0)
        return Step(y5: y5, y4: y4, kLast: k7, errorNorm: diff.infinityNorm)
    }
}
