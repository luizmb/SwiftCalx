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

fileprivate extension RungeKutta45 {
    /// Time offsets at which the seven stages are evaluated, relative to `t`.
    /// `c1 = 0` (the start of the step) is implicit and omitted.
    enum C {
        static let c2 = 1.0 / 5.0
        static let c3 = 3.0 / 10.0
        static let c4 = 4.0 / 5.0
        static let c5 = 8.0 / 9.0
        static let c6 = 1.0
        static let c7 = 1.0
    }

    /// Inter-stage weights — the `a[i][j]` from the Butcher tableau, naming the
    /// fields directly so the recurrence reads like the textbook.
    enum A {
        static let a21 = 1.0 / 5.0

        static let a31 = 3.0 / 40.0
        static let a32 = 9.0 / 40.0

        static let a41 = 44.0 / 45.0
        static let a42 = -56.0 / 15.0
        static let a43 = 32.0 / 9.0

        static let a51 = 19_372.0 / 6_561.0
        static let a52 = -25_360.0 / 2_187.0
        static let a53 = 64_448.0 / 6_561.0
        static let a54 = -212.0 / 729.0

        static let a61 = 9_017.0 / 3_168.0
        static let a62 = -355.0 / 33.0
        static let a63 = 46_732.0 / 5_247.0
        static let a64 = 49.0 / 176.0
        static let a65 = -5_103.0 / 18_656.0

        // a7i double as the b5 weights (FSAL property).
        // a72 = 0 — canonical-tableau zero, elided from code.
        static let a71 = 35.0 / 384.0
        static let a73 = 500.0 / 1_113.0
        static let a74 = 125.0 / 192.0
        static let a75 = -2_187.0 / 6_784.0
        static let a76 = 11.0 / 84.0
    }

    /// 5th-order solution weights. Equal to `a7*` (FSAL).
    /// b2 = b7 = 0 — canonical-tableau zeroes, elided from code.
    enum B5 {
        static let b1 = A.a71
        static let b3 = A.a73
        static let b4 = A.a74
        static let b5 = A.a75
        static let b6 = A.a76
    }

    /// 4th-order embedded weights — used to estimate the local truncation error.
    /// b2 = 0 — canonical-tableau zero, elided from code.
    enum B4 {
        static let b1 = 5_179.0 / 57_600.0
        static let b3 = 7_571.0 / 16_695.0
        static let b4 = 393.0 / 640.0
        static let b5 = -92_097.0 / 339_200.0
        static let b6 = 187.0 / 2_100.0
        static let b7 = 1.0 / 40.0
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
    }

    /// Compute one Dormand–Prince step from `(t, y)` of size `h`, given the
    /// initial slope `k1 = f(t, y)`. Returns the embedded pair + error norm
    /// without judging acceptability — see ``trajectory(from:derivative:startingAt:through:tolerance:initialStep:minStep:maxStep:maxIterations:)``
    /// for the adaptive driver that does the accept/reject + step-size logic.
    static func step<State: NormedVectorState>(
        from t: Double,
        y: State,
        k1: State,
        size h: Double,
        derivative f: @Sendable (Double, State) -> State
    ) -> Step<State> where State.Scalar == Double {
        // Each stage's input state is built from k1..k_{i-1} as a sum of scaled
        // states. We break each combination into individually-typed `let`s so
        // the Swift type-checker has a tractable expression at each step
        // (otherwise a single deeply-nested `y + h * (a₁k₁ + a₂k₂ + …)` blows
        // up generic resolution time on `+` / `*`).

        let k2 = f(t + C.c2 * h, y + (h * A.a21) * k1)

        let s3a = (h * A.a31) * k1
        let s3b = (h * A.a32) * k2
        let k3 = f(t + C.c3 * h, y + s3a + s3b)

        let s4a = (h * A.a41) * k1
        let s4b = (h * A.a42) * k2
        let s4c = (h * A.a43) * k3
        let k4 = f(t + C.c4 * h, y + s4a + s4b + s4c)

        let s5a = (h * A.a51) * k1
        let s5b = (h * A.a52) * k2
        let s5c = (h * A.a53) * k3
        let s5d = (h * A.a54) * k4
        let k5 = f(t + C.c5 * h, y + s5a + s5b + s5c + s5d)

        let s6a = (h * A.a61) * k1
        let s6b = (h * A.a62) * k2
        let s6c = (h * A.a63) * k3
        let s6d = (h * A.a64) * k4
        let s6e = (h * A.a65) * k5
        let k6 = f(t + C.c6 * h, y + s6a + s6b + s6c + s6d + s6e)

        // 5th-order solution. B5.b2 and B5.b7 are zero, so those terms drop out.
        let y5a = (h * B5.b1) * k1
        let y5b = (h * B5.b3) * k3
        let y5c = (h * B5.b4) * k4
        let y5d = (h * B5.b5) * k5
        let y5e = (h * B5.b6) * k6
        let y5 = y + y5a + y5b + y5c + y5d + y5e

        // k7 = f(t + h, y5) — the FSAL stage. Used in the 4th-order estimate
        // *and* reused as next step's k1 when this step is accepted.
        let k7 = f(t + C.c7 * h, y5)

        // 4th-order embedded estimate. B4.b2 is zero.
        let y4a = (h * B4.b1) * k1
        let y4b = (h * B4.b3) * k3
        let y4c = (h * B4.b4) * k4
        let y4d = (h * B4.b5) * k5
        let y4e = (h * B4.b6) * k6
        let y4f = (h * B4.b7) * k7
        let y4 = y + y4a + y4b + y4c + y4d + y4e + y4f

        // Error = ||y5 − y4|| in the infinity norm. We compute `y5 − y4` as
        // `y5 + (−1)·y4` since VectorState only requires `+` and scalar `*`.
        let diff = y5 + (-1.0) * y4
        return Step(y5: y5, y4: y4, kLast: k7, errorNorm: diff.infinityNorm)
    }
}
