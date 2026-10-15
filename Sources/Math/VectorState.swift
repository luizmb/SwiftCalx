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
    /// Elementwise sum. Built-in vector conformers (`Array`, `AcceleratedVector`) combine
    /// operands of different lengths like `zip`: the result is as long as the shorter one.
    static func + (lhs: Self, rhs: Self) -> Self
    static func * (scalar: Scalar, state: Self) -> Self

    /// `self = self + scalar * other`, the step every RK stage repeats. Same result as the
    /// two operators; conformers that own a buffer (`Array`) write into it instead of
    /// building two new states. The default implementation uses the operators.
    mutating func add(_ other: Self, scaledBy scalar: Scalar)
}

public extension VectorState {
    @inlinable
    mutating func add(_ other: Self, scaledBy scalar: Scalar) {
        // `scalar * other + self`: IEEE addition commutes, so this is bit-for-bit `self + …`.
        self = scalar * other + self
    }
}

extension Array: VectorState where Element: ℝ {
    public typealias Scalar = Element

    /// Elementwise sum. Like `zip`, the result is as long as the shorter operand.
    @inlinable
    public static func + (lhs: [Element], rhs: [Element]) -> [Element] {
        lhs.elementwise(rhs, +)
    }

    @inlinable
    public static func * (scalar: Element, state: [Element]) -> [Element] {
        state.scaled(by: scalar)
    }

    /// In place: `self[i] = self[i] + scalar * other[i]` (no allocation unless the buffer is
    /// shared). Like `+`, the result is as long as the shorter operand.
    @inlinable
    public mutating func add(_ other: [Element], scaledBy scalar: Element) {
        formElementwise(other) { lhs, rhs in lhs + scalar * rhs }
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
