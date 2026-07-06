// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
import RealNumber

/// A strategy for choosing the step size `h` used by a finite-difference derivative
/// formula at a given point.
///
/// `StepCalculator` is a *witness*: a struct holding the chosen-`h` function as a
/// value, rather than an enum-of-cases. That keeps the type open for extension —
/// anyone can write `StepCalculator { x, fn in ... }` to plug in a new strategy —
/// while still giving the standard strategies a uniform call site via static
/// factories (`.epsilonSquareRoot`, `.adaptative`, …).
///
/// For non-degenerate behaviour the chosen `h` must be strictly greater than 0 and
/// small enough that `x ± h` evaluates inside the function's domain.
///
/// References:
/// - https://en.wikipedia.org/wiki/Numerical_differentiation#Step_size
public struct StepCalculator<Scalar: ℝ>: Sendable {
    public let calculate: @Sendable (Scalar, Fn<Scalar>) -> Scalar

    public init(_ calculate: @escaping @Sendable (Scalar, Fn<Scalar>) -> Scalar) {
        self.calculate = calculate
    }
}

public extension StepCalculator {
    /// `h = √ε`. Optimal for one-sided differences (Newton/backward) where the leading
    /// truncation error is `O(h)` and round-off is `O(ε/h)`; balancing them gives `h ~ √ε`.
    static var epsilonSquareRoot: Self {
        Self { _, _ in Scalar.epsilon.squareRoot() }
    }

    /// `h = ∛ε`. Optimal for symmetric central differences (truncation `O(h²)`,
    /// round-off `O(ε/h)`; balance gives `h ~ ε^(1/3)`).
    static var epsilonCubeRoot: Self {
        Self { _, _ in Scalar.epsilon.cubeRoot() }
    }

    /// `h = √ε · x`. Scales with the magnitude of the evaluation point — useful when
    /// `x` ranges over several orders of magnitude. Degenerates to `0` at `x = 0`;
    /// use ``adaptativeZeroHigh`` if your evaluation might land exactly on the origin.
    static var adaptative: Self {
        Self { x, _ in Scalar.epsilon.squareRoot() * x }
    }

    /// Like ``adaptative`` but falls back to `ε` at `x = 0` so a derivative there
    /// still gets a non-zero step.
    static var adaptativeZeroHigh: Self {
        Self { x, _ in x == 0 ? Scalar.epsilon : Scalar.epsilon.squareRoot() * x }
    }

    /// A constant `h`, useful for tests with known accuracy and for matching
    /// hand-computed reference values.
    static func constant(_ h: Scalar) -> Self {
        Self { _, _ in h }
    }

    /// A user-supplied function `x ↦ h(x)`. Lets the caller encode any
    /// problem-specific step heuristic without writing a new `StepCalculator`.
    static func customHforX(_ hForX: Fn<Scalar>) -> Self {
        Self { x, _ in hForX(x) }
    }
}
