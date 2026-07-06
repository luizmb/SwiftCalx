// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
import Math
import RealNumber

/// Pairs a function `f` with a `DerivativeMethod` to obtain a numerical
/// derivative `Fn` that can be evaluated at any point.
///
/// `DerivativeFunction` is a small struct — it just remembers the underlying
/// function and the method to apply, and exposes the resulting slope function.
/// All the algorithmic variety (which stencil, what step strategy, what order)
/// lives in ``DerivativeMethod``, which is open-extensible thanks to the witness
/// pattern.
public struct DerivativeFunction<Scalar: ℝ>: Sendable {
    /// The function being differentiated. Differentiating again starts from this
    /// function's *slope* (via composition), not the original.
    public let underlyingFunction: Fn<Scalar>
    public let method: DerivativeMethod<Scalar>

    public init(underlyingFunction: Fn<Scalar>, method: DerivativeMethod<Scalar>) {
        self.underlyingFunction = underlyingFunction
        self.method = method
    }

    public var order: Int { method.order }
    public var slopeFunction: Fn<Scalar> { method.deriving(underlyingFunction) }

    public func callAsFunction(x: Scalar) -> Scalar { slopeFunction(x) }

    /// Perpendicular-slope function: at every point, `−1 / slopeFunction(x)`. If
    /// the slope is a tangent, this is the slope of the line perpendicular to it.
    public func perpendicular() -> Fn<Scalar> {
        slopeFunction.perpendicularSlope()
    }

    /// True if the underlying function looks differentiable at `x` to the working
    /// step `h`: the backward and forward difference quotients agree to within `√h`.
    ///
    /// The `√h` (not `h`) tolerance matters: smooth functions have one-sided
    /// truncation error of order `O(h)`, so a `< h` threshold would reject them.
    /// Corners (`|x|` at 0) have a constant slope jump independent of `h` —
    /// they fail the `√h` threshold cleanly. Vertical-tangent points (`x^(1/3)`
    /// at 0) also fail because Swift's `pow(-h, 1/3)` returns `NaN`, which
    /// propagates through the `<` comparison as `false`.
    public func isDifferentiable(at x: Scalar, h: Scalar) -> Bool {
        let fn = underlyingFunction
        let fromLeft = (fn(x) - fn(x - h)) / h
        let fromRight = (fn(x + h) - fn(x)) / h
        return abs(fromLeft - fromRight) < h.squareRoot()
    }

    /// Differentiate the slope again, re-using the same method. **Accuracy degrades**
    /// with each chain — see ``DerivativeMethod/Compose/repeated(_:times:)``. Prefer
    /// passing an explicit direct higher-order method (e.g.
    /// `CentralStencil.fivePoint(order: 4, …)`) via ``differentiate(method:)``.
    public func differentiate() -> DerivativeFunction<Scalar> {
        differentiate(method: method)
    }

    /// Differentiate the slope again with a new method. Useful for switching from
    /// a chained 1st-order method to a direct higher-order one without rebuilding
    /// the whole pipeline.
    public func differentiate(method: DerivativeMethod<Scalar>) -> DerivativeFunction<Scalar> {
        DerivativeFunction(underlyingFunction: slopeFunction, method: method)
    }
}

public extension Endo where A: ℝ {
    /// Wrap this function as the underlying of a ``DerivativeFunction`` driven by
    /// `method`. Entry point into the calculus pipeline.
    func differentiate(method: DerivativeMethod<A>) -> DerivativeFunction<A> {
        DerivativeFunction(underlyingFunction: self, method: method)
    }

    func point(at x: A) -> BidimensionalPoint<A>? {
        let y = self(x)
        guard !x.isNaN, !y.isNaN else { return nil }
        return BidimensionalPoint(x: x, y: y)
    }

    /// Returns the perpendicular-slope function: at every point, the negative
    /// reciprocal of `self(x)`. If `self` is a tangent slope, this is the slope
    /// of the line perpendicular to it.
    func perpendicularSlope() -> Self {
        Self { x in -1 / self(x) }
    }
}
