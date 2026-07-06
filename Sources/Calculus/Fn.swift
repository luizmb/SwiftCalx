// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
import RealNumber

/// A real-valued endomorphism — a function `(T) -> T` over some real-number type `T`.
///
/// `Fn<T>` is a thin numerical-context typealias over `CoreFP.Endo<T>`. It lets the
/// calculus algorithms in this library spell their input shape briefly:
///
/// ```swift
/// let square: Fn<Double> = Fn { $0 * $0 }
/// let derivative = square.differentiate(method: .symmetricDifferenceQuotient(.epsilonSquareRoot))
/// ```
///
/// All of `Endo`'s API surface — `init(_:)`, `callAsFunction(_:)`, `Semigroup`
/// composition with `<>`, `mconcat`, etc. — is available, plus the calculus-specific
/// `differentiate(method:)`, `point(at:)`, `invert()` extensions defined in
/// ``DerivativeFunction``.
public typealias Fn<NumericType> = Endo<NumericType> where NumericType: ℝ
