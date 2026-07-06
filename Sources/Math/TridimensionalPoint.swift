// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
import RealNumber

public struct TridimensionalPoint<T: ℝ>: Sendable, Equatable {
    public let x: T
    public let y: T
    public let z: T

    public init(x: T, y: T, z: T) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - Vector space

public extension TridimensionalPoint {
    /// The additive identity: the origin point `(0, 0, 0)`. Combined with
    /// elementwise `+` and scalar `*`, makes `TridimensionalPoint` a vector space
    /// over `T`.
    static var zero: TridimensionalPoint {
        TridimensionalPoint(x: .zero, y: .zero, z: .zero)
    }

    static func + (lhs: TridimensionalPoint, rhs: TridimensionalPoint) -> TridimensionalPoint {
        TridimensionalPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: TridimensionalPoint, rhs: TridimensionalPoint) -> TridimensionalPoint {
        TridimensionalPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func * (scalar: T, point: TridimensionalPoint) -> TridimensionalPoint {
        TridimensionalPoint(x: scalar * point.x, y: scalar * point.y, z: scalar * point.z)
    }
}

extension TridimensionalPoint: VectorState {
    public typealias Scalar = T
}

// MARK: - Monoid (under elementwise addition)

extension TridimensionalPoint: Semigroup {
    public static func combine(_ lhs: TridimensionalPoint, _ rhs: TridimensionalPoint) -> TridimensionalPoint {
        lhs + rhs
    }
}

extension TridimensionalPoint: Monoid {
    public static var identity: TridimensionalPoint { .zero }
}
