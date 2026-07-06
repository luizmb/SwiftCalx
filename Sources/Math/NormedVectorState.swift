// SPDX-License-Identifier: Apache-2.0

import Foundation
import RealNumber

/// A ``VectorState`` that also exposes its **infinity norm** — the largest absolute
/// component value (or just `|self|` for scalars).
///
/// Adaptive ODE solvers (RKF45, Dormand-Prince) compare the magnitude of the local
/// truncation error against a tolerance to decide whether to accept a step. The
/// natural quantity is a norm of the difference between the high-order and
/// low-order embedded estimates; infinity norm is the simplest, well-behaved
/// choice (no floating-point sum of squares, no overflow on large states, and
/// component-by-component meaning).
///
/// Built-in conformances cover the typical biokinetic / ODE-system cases:
/// - `Array<Element>` where `Element: ℝ` — `max |y_i|` across the components.
/// - `Double`, `Float`, `Decimal`, `Float16`, `Float80` — each is its own
///   one-dimensional vector space, so the norm collapses to `magnitude`.
public protocol NormedVectorState: VectorState {
    /// The infinity norm: `max |component|`. For scalar conformers, just
    /// `magnitude`.
    var infinityNorm: Scalar { get }
}

extension Array: NormedVectorState where Element: ℝ {
    public var infinityNorm: Element {
        reduce(Element.zero) { acc, x in
            let m = x < .zero ? -x : x
            return m > acc ? m : acc
        }
    }
}

extension Double: NormedVectorState { public var infinityNorm: Double { magnitude } }
extension Float: NormedVectorState { public var infinityNorm: Float { magnitude } }
extension Decimal: NormedVectorState {
    public var infinityNorm: Decimal { self < 0 ? -self : self }
}

#if !((os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64))
    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    extension Float16: NormedVectorState { public var infinityNorm: Float16 { magnitude } }
#endif

#if (arch(i386) || arch(x86_64)) && !os(Windows) && !os(Android)
    extension Float80: NormedVectorState { public var infinityNorm: Float80 { magnitude } }
#endif
