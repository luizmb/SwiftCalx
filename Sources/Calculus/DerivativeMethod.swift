// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
import RealNumber

/// A numerical-differentiation method — *the recipe* for turning a function `f`
/// into an approximation of its `order`-th derivative `f^(order)`.
///
/// `DerivativeMethod` is a **witness** type: a struct that holds the deriving
/// function as a value, rather than a protocol or an enum-of-cases. That keeps
/// the type open for extension — anyone can write their own method by calling
/// `DerivativeMethod(order: …, deriving: …)` — while still letting the standard
/// methods live behind tidy namespaced factories like
/// `DerivativeMethod<Double>.CentralStencil.fivePoint(order: 2, step: .adaptative)`.
///
/// The wrapped closure is **pure**: given the same input `Fn`, it always returns
/// the same derivative `Fn`. The actual numerical work (multiple `f(x ± h)`
/// evaluations, weighted sum, division by a power of `h`) happens when the
/// returned `Fn` is called with a concrete `x`.
///
/// ## Namespaces and standalone factories
///
/// Methods with multiple variants live under nested `public enum` namespaces so
/// the variants surface together in code completion:
///
/// - ``CentralStencil`` — symmetric stencils centred on `x` (most accurate per
///   evaluation; needs `f` defined on both sides of `x`). Variants: `threePoint`,
///   `fivePoint`.
/// - ``ForwardStencil`` — one-sided stencils using `x, x+h, x+2h, …`. Use near a
///   left boundary of the domain. Variants: `twoPoint`, `threePoint`.
/// - ``BackwardStencil`` — one-sided stencils using `x, x-h, x-2h, …`. Use near a
///   right boundary. Variants: `twoPoint`, `threePoint`.
/// - ``Compose`` — combinators that build new methods from existing ones
///   (e.g. ``Compose/repeated(_:times:)`` for naïve higher-order chains).
///
/// Standalone author-named factories (each is a single method, so it lives flat
/// alongside the namespaces above for one-tap discoverability):
///
/// - ``richardsonExtrapolation(coarse:fine:leadingOrder:)`` — Richardson 1911:
///   combine two evaluations at `h` and `h/2` to cancel the leading error term.
/// - ``fornbergCentralStencil(points:order:step:)`` — Fornberg 1988: generate
///   optimal central-stencil weights for any (points, order) combo at construction
///   time. The escape hatch when none of the hardcoded stencils fits.
/// - ``custom(order:deriving:)`` — raw witness escape hatch when you have a
///   completely custom method in mind.
///
/// References:
/// - Fornberg, B. (1988). *Generation of finite difference formulas on arbitrarily
///   spaced grids*. Mathematics of Computation 51(184): 699–706.
/// - https://en.wikipedia.org/wiki/Finite_difference_coefficient
/// - Press et al., *Numerical Recipes*, §5.7 (Numerical Derivatives).
public struct DerivativeMethod<Scalar: ℝ>: Sendable {
    /// Derivative order: `1` for `f'`, `2` for `f''`, …
    public let order: Int

    /// Turns the function `f` into an approximation of `f^(order)`.
    public let deriving: @Sendable (Fn<Scalar>) -> Fn<Scalar>

    /// The raw escape hatch — use this if no built-in method fits. Most users want
    /// one of the namespaced factories (`CentralStencil.fivePoint`, etc.).
    public static func custom(
        order: Int,
        deriving: @escaping @Sendable (Fn<Scalar>) -> Fn<Scalar>
    ) -> Self {
        Self(order: order, deriving: deriving)
    }

    public init(order: Int, deriving: @escaping @Sendable (Fn<Scalar>) -> Fn<Scalar>) {
        self.order = order
        self.deriving = deriving
    }
}

// MARK: - Central stencils (symmetric around x)

extension DerivativeMethod {
    /// Central (symmetric) finite-difference stencils around `x`.
    ///
    /// All factories take a `derivative order` ∈ {1, 2, …} and a `StepCalculator`.
    /// If the requested order is outside the supported range for a given stencil,
    /// the resulting method evaluates to `NaN` at every point — `NaN` propagates
    /// naturally through numerical code and avoids any `fatalError`-style trap.
    public enum CentralStencil {
        /// Three-point central stencil. Supported orders: **1** and **2**.
        ///
        /// - `order 1`: `f'(x) ≈ [f(x+h) − f(x−h)] / (2h)` — error `O(h²)`.
        /// - `order 2`: `f''(x) ≈ [f(x+h) − 2·f(x) + f(x−h)] / h²` — error `O(h²)`.
        ///
        /// Exact for polynomials of degree ≤ 2 (order 1) or ≤ 3 (order 2).
        public static func threePoint(order: Int, step: StepCalculator<Scalar>) -> DerivativeMethod<Scalar> {
            switch order {
            case 1:
                DerivativeMethod(order: 1) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (fn(x + h) - fn(x - h)) / (2 * h)
                    }
                }
            case 2:
                DerivativeMethod(order: 2) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (fn(x + h) - 2 * fn(x) + fn(x - h)) / (h * h)
                    }
                }
            default:
                .nanMethod(order: order)
            }
        }

        /// Five-point central stencil. Supported orders: **1, 2, 3, 4**.
        ///
        /// - `order 1`: `[−f(x+2h) + 8·f(x+h) − 8·f(x−h) + f(x−2h)] / (12h)` — error `O(h⁴)`.
        /// - `order 2`: `[−f(x+2h) + 16·f(x+h) − 30·f(x) + 16·f(x−h) − f(x−2h)] / (12h²)` — error `O(h⁴)`.
        /// - `order 3`: `[f(x+2h) − 2·f(x+h) + 2·f(x−h) − f(x−2h)] / (2h³)` — error `O(h²)`.
        /// - `order 4`: `[f(x+2h) − 4·f(x+h) + 6·f(x) − 4·f(x−h) + f(x−2h)] / h⁴` — error `O(h²)`.
        ///
        /// Strictly more accurate than ``threePoint(order:step:)`` at the cost of two
        /// extra function evaluations per derivative call.
        public static func fivePoint(order: Int, step: StepCalculator<Scalar>) -> DerivativeMethod<Scalar> {
            switch order {
            case 1:
                DerivativeMethod(order: 1) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (-fn(x + 2 * h) + 8 * fn(x + h) - 8 * fn(x - h) + fn(x - 2 * h)) / (12 * h)
                    }
                }
            case 2:
                DerivativeMethod(order: 2) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (-fn(x + 2 * h) + 16 * fn(x + h) - 30 * fn(x) + 16 * fn(x - h) - fn(x - 2 * h)) / (12 * h * h)
                    }
                }
            case 3:
                DerivativeMethod(order: 3) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (fn(x + 2 * h) - 2 * fn(x + h) + 2 * fn(x - h) - fn(x - 2 * h)) / (2 * h * h * h)
                    }
                }
            case 4:
                DerivativeMethod(order: 4) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (fn(x + 2 * h) - 4 * fn(x + h) + 6 * fn(x) - 4 * fn(x - h) + fn(x - 2 * h)) / (h * h * h * h)
                    }
                }
            default:
                .nanMethod(order: order)
            }
        }
    }

    /// Sentinel: a method that always evaluates to `NaN`. Returned by stencil
    /// factories when the requested derivative order is outside their supported
    /// range. `NaN` propagates through downstream arithmetic without crashing,
    /// keeping the no-`fatalError` invariant.
    fileprivate static func nanMethod(order: Int) -> DerivativeMethod<Scalar> {
        DerivativeMethod(order: order) { _ in
            Fn { _ in Scalar.notANumber }
        }
    }
}

// MARK: - One-sided stencils (forward / backward)

public extension DerivativeMethod {
    /// Forward finite-difference stencils using `x, x+h, x+2h, …`.
    /// Use near a left boundary of the function's domain where backward / central
    /// stencils would fall outside.
    enum ForwardStencil {
        /// Two-point forward (Newton quotient): `f'(x) ≈ [f(x+h) − f(x)] / h`. Error `O(h)`.
        public static func twoPoint(order: Int = 1, step: StepCalculator<Scalar>) -> DerivativeMethod<Scalar> {
            guard order == 1 else { return .nanMethod(order: order) }
            return DerivativeMethod(order: 1) { fn in
                Fn { x in
                    let h = step.calculate(x, fn)
                    return (fn(x + h) - fn(x)) / h
                }
            }
        }

        /// Three-point forward stencil. Supported orders: **1** and **2**.
        ///
        /// - `order 1`: `[−3·f(x) + 4·f(x+h) − f(x+2h)] / (2h)` — error `O(h²)`.
        /// - `order 2`: `[f(x) − 2·f(x+h) + f(x+2h)] / h²` — error `O(h)`.
        public static func threePoint(order: Int, step: StepCalculator<Scalar>) -> DerivativeMethod<Scalar> {
            switch order {
            case 1:
                DerivativeMethod(order: 1) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (-3 * fn(x) + 4 * fn(x + h) - fn(x + 2 * h)) / (2 * h)
                    }
                }
            case 2:
                DerivativeMethod(order: 2) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (fn(x) - 2 * fn(x + h) + fn(x + 2 * h)) / (h * h)
                    }
                }
            default:
                .nanMethod(order: order)
            }
        }
    }

    /// Backward finite-difference stencils using `x, x-h, x-2h, …`.
    /// Use near a right boundary of the function's domain.
    enum BackwardStencil {
        /// Two-point backward: `f'(x) ≈ [f(x) − f(x−h)] / h`. Error `O(h)`.
        public static func twoPoint(order: Int = 1, step: StepCalculator<Scalar>) -> DerivativeMethod<Scalar> {
            guard order == 1 else { return .nanMethod(order: order) }
            return DerivativeMethod(order: 1) { fn in
                Fn { x in
                    let h = step.calculate(x, fn)
                    return (fn(x) - fn(x - h)) / h
                }
            }
        }

        /// Three-point backward. Supported orders: **1** and **2**.
        ///
        /// - `order 1`: `[3·f(x) − 4·f(x−h) + f(x−2h)] / (2h)` — error `O(h²)`.
        /// - `order 2`: `[f(x) − 2·f(x−h) + f(x−2h)] / h²` — error `O(h)`.
        public static func threePoint(order: Int, step: StepCalculator<Scalar>) -> DerivativeMethod<Scalar> {
            switch order {
            case 1:
                DerivativeMethod(order: 1) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (3 * fn(x) - 4 * fn(x - h) + fn(x - 2 * h)) / (2 * h)
                    }
                }
            case 2:
                DerivativeMethod(order: 2) { fn in
                    Fn { x in
                        let h = step.calculate(x, fn)
                        return (fn(x) - 2 * fn(x - h) + fn(x - 2 * h)) / (h * h)
                    }
                }
            default:
                .nanMethod(order: order)
            }
        }
    }
}

// MARK: - Richardson extrapolation (accuracy-boosting combinator)

public extension DerivativeMethod where Scalar == Double {
    /// Richardson extrapolation — turns a method of error `O(h^p)` into one of
    /// error `O(h^(p+q))` by combining two evaluations at different step sizes.
    ///
    /// **The trick**: if `M(h)` is the method's estimate using step `h`, and the
    /// leading error term is `c·h^p`, then
    ///
    /// > `(2^p · M(h/2) − M(h)) / (2^p − 1)  =  f'(x) + O(h^(p+q))`
    ///
    /// cancels the leading `c·h^p` term, leaving error of higher order.
    ///
    /// The witness pattern shines here: the API takes **two pre-built methods** —
    /// one with the coarse step `h`, one with the fine step `h/2` — and combines
    /// their derivings. No magic; the caller can pair stencils of different
    /// families (e.g. coarse 3-point + fine 5-point) for custom extrapolations.
    ///
    /// The `leadingOrder` is the `p` in the methods' `O(h^p)` error term — `2` for
    /// central differences, `1` for one-sided. Both methods must have the same
    /// derivative order; the result's order matches them.
    ///
    /// Restricted to `Scalar == Double` so the `2^p` weighting can use stdlib
    /// `pow` without ℝ-generic integer-literal gymnastics. For non-Double scalars,
    /// build the combination by hand or extend this method.
    ///
    /// References:
    /// - Richardson, L.F. (1911). *The approximate arithmetical solution by
    ///   finite differences of physical problems …*. Philosophical Transactions
    ///   of the Royal Society A 210: 307–357.
    /// - https://en.wikipedia.org/wiki/Richardson_extrapolation
    static func richardsonExtrapolation(
        coarse: DerivativeMethod<Double>,
        fine: DerivativeMethod<Double>,
        leadingOrder: Int = 2
    ) -> DerivativeMethod<Double> {
        let twoToTheP = pow(2.0, Double(leadingOrder))
        return DerivativeMethod(order: coarse.order) { fn in
            let coarseFn = coarse.deriving(fn)
            let fineFn = fine.deriving(fn)
            return Fn { x in
                (twoToTheP * fineFn(x) - coarseFn(x)) / (twoToTheP - 1)
            }
        }
    }
}

// MARK: - Composition combinators

public extension DerivativeMethod {
    /// Combinators that build new methods from existing ones.
    enum Compose {
        /// Apply `method` to its own output `times` times.
        ///
        /// For `times = 2` and `method` of order `m`, the result approximates the
        /// `2m`-th derivative — but with compounded step-size and round-off error,
        /// since each composition effectively doubles the working `h`. **Prefer a
        /// direct higher-order stencil** (e.g. `CentralStencil.fivePoint(order: 4, …)`)
        /// when one exists; reach for `repeated` only when you need an arbitrary
        /// higher order and no direct formula is available.
        public static func repeated(_ method: DerivativeMethod<Scalar>, times: Int) -> DerivativeMethod<Scalar> {
            guard times > 0 else {
                return DerivativeMethod(order: 0) { fn in fn }
            }
            return (1 ..< times).reduce(method) { acc, _ in
                DerivativeMethod(order: acc.order + method.order) { fn in
                    method.deriving(acc.deriving(fn))
                }
            }
        }
    }
}

// MARK: - Scalar == Double specialisations (Fornberg)

public extension DerivativeMethod where Scalar == Double {
    /// Custom central stencil with arbitrary `points` (odd) and `order`
    /// (1 ≤ order ≤ points − 1). Stencil weights are computed at construction
    /// time using **Fornberg's algorithm** (1988), which produces the optimal
    /// finite-difference coefficients for any set of grid points.
    ///
    /// This is the open-ended escape hatch: use it when none of the hardcoded
    /// stencils above fits your accuracy / point-count requirements.
    ///
    /// **Restricted to `Scalar == Double`** because Fornberg's recurrence needs
    /// rational arithmetic that's painful to express generically over `ℝ` types
    /// without an `Int → Scalar` bridge. If you have a non-`Double` use case,
    /// reach out — generalising is a code change, not a math change.
    static func fornbergCentralStencil(
        points: Int,
        order: Int,
        step: StepCalculator<Double>
    ) -> DerivativeMethod<Double> {
        guard points >= 2, points % 2 == 1, order >= 1, order < points else {
            return .nanMethod(order: order)
        }
        let half = (points - 1) / 2
        let stencilPoints = (-half ... half).map { Double($0) }
        let weights = fornbergWeights(at: 0, points: stencilPoints, derivativeOrder: order)
        return DerivativeMethod(order: order) { fn in
            Fn { x in
                let h = step.calculate(x, fn)
                let weighted = (0 ..< points).reduce(0.0) { acc, i in
                    let offset = stencilPoints[i] * h
                    return acc + weights[i] * fn(x + offset)
                }
                return weighted / pow(h, Double(order))
            }
        }
    }
}

/// Fornberg's algorithm (1988) for finite-difference weights at point `z` from a
/// stencil of grid points, evaluating the derivative of order `derivativeOrder`.
///
/// Returns `weights[i]` such that `f^(derivativeOrder)(z) ≈ Σ weights[i] · f(points[i])`.
/// (No division by `h^order` — the caller does that based on its own step.)
///
/// Reference: Fornberg, B. (1988). *Generation of finite difference formulas on
/// arbitrarily spaced grids*. Math. Comp. 51(184): 699–706.
func fornbergWeights(
    at z: Double,
    points: [Double],
    derivativeOrder m: Int
) -> [Double] {
    let n = points.count
    var c = Array(repeating: Array(repeating: 0.0, count: m + 1), count: n)
    c[0][0] = 1
    var c1 = 1.0
    var c4 = points[0] - z
    for i in 1 ..< n {
        let mn = min(i, m)
        var c2 = 1.0
        let c5 = c4
        c4 = points[i] - z
        for j in 0 ..< i {
            let c3 = points[i] - points[j]
            c2 *= c3
            // When j == i − 1, update c[i, …] FIRST — it reads c[i − 1, …] = c[j, …]
            // which we're about to overwrite. Order matters; the Python reference
            // does this same dance inside the j loop.
            if j == i - 1 {
                if mn >= 1 {
                    for k in stride(from: mn, through: 1, by: -1) {
                        c[i][k] = c1 * (Double(k) * c[i - 1][k - 1] - c5 * c[i - 1][k]) / c2
                    }
                }
                c[i][0] = -c1 * c5 * c[i - 1][0] / c2
            }
            if mn >= 1 {
                for k in stride(from: mn, through: 1, by: -1) {
                    c[j][k] = (c4 * c[j][k] - Double(k) * c[j][k - 1]) / c3
                }
            }
            c[j][0] = c4 * c[j][0] / c3
        }
        c1 = c2
    }
    return c.map { $0[m] }
}
