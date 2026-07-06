// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Math
import RealNumber

public extension DerivativeMethod {
    /// Compose two methods left-to-right: apply `self` first, then `other` to
    /// the resulting slope function. Orders add.
    ///
    /// **Accuracy caveat**: chaining stencils compounds truncation error — the
    /// composed method's effective accuracy is typically lower than a direct
    /// higher-order method tuned for that order. Prefer
    /// ``CentralStencil/fivePoint(order:step:)`` (etc.) when a direct method exists.
    func then(_ other: DerivativeMethod<Scalar>) -> DerivativeMethod<Scalar> {
        DerivativeMethod(order: order + other.order) { f in
            other.deriving(self.deriving(f))
        }
    }
}

// MARK: - Monoid (under left-to-right composition)

//
// Composition is the only canonical monoid on `DerivativeMethod` — there's no
// competing notion of "combine" the way `Double` has both `+` and `*`. So
// `DerivativeMethod` conforms directly, the same way FP conforms `String` and
// `Array` directly to `Monoid` under concatenation rather than wrapping them
// in a newtype.

extension DerivativeMethod: Semigroup {
    public static func combine(
        _ lhs: DerivativeMethod<Scalar>,
        _ rhs: DerivativeMethod<Scalar>
    ) -> DerivativeMethod<Scalar> {
        lhs.then(rhs)
    }
}

extension DerivativeMethod: Monoid {
    /// The no-op derivative method: returns the input function unchanged, claims
    /// order 0. Identity for left-to-right composition via ``then(_:)``.
    public static var identity: DerivativeMethod<Scalar> {
        DerivativeMethod(order: 0) { $0 }
    }
}
