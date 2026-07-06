// SPDX-License-Identifier: Apache-2.0

import Foundation
import RealNumber

/// State type for the operations RK-style integrators perform between substeps:
/// elementwise addition with another state, and scaling by a real-number coefficient.
///
/// Conform any type that behaves as a vector over an ``ℝ`` scalar. Built-in
/// conformances:
///
/// - `Array<Element>` where `Element: ℝ` — elementwise `+` and elementwise scalar `*`.
///   The natural way to spell a state vector for a multi-compartment ODE system.
/// - `Double`, `Float`, `Decimal`, `Float16`, `Float80` — every concrete ``ℝ`` type
///   is its own one-dimensional vector space with `Scalar == Self`. Lets the *same*
///   algorithm namespaces (e.g. ``SimpsonWeightedAverage``) drive both scalar and
///   vector solvers without writing the implementation twice.
public protocol VectorState: Sendable {
    associatedtype Scalar: ℝ
    static func + (lhs: Self, rhs: Self) -> Self
    static func * (scalar: Scalar, state: Self) -> Self
}

extension Array: VectorState where Element: ℝ {
    public typealias Scalar = Element

    public static func + (lhs: [Element], rhs: [Element]) -> [Element] {
        Swift.zip(lhs, rhs).map(+)
    }

    public static func * (scalar: Element, state: [Element]) -> [Element] {
        state.map { scalar * $0 }
    }
}

extension Double: VectorState { public typealias Scalar = Double }
extension Float: VectorState { public typealias Scalar = Float }
extension Decimal: VectorState { public typealias Scalar = Decimal }

#if !((os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64))
    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    extension Float16: VectorState { public typealias Scalar = Float16 }
#endif

#if (arch(i386) || arch(x86_64)) && !os(Windows) && !os(Android)
    extension Float80: VectorState { public typealias Scalar = Float80 }
#endif
