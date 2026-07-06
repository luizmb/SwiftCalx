// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
import RealNumber

public struct BidimensionalPoint<T: ℝ>: Sendable, Equatable {
    public let x: T
    public let y: T

    public init(x: T, y: T) {
        self.x = x
        self.y = y
    }

    public func slope(to another: BidimensionalPoint) -> T {
        Math.slope(point: self, anotherPoint: another)
    }
}

// MARK: - Vector space

public extension BidimensionalPoint {
    /// The additive identity: the origin point `(0, 0)`. Combined with elementwise
    /// `+` and scalar `*`, makes `BidimensionalPoint` a vector space over `T`.
    static var zero: BidimensionalPoint {
        BidimensionalPoint(x: .zero, y: .zero)
    }

    static func + (lhs: BidimensionalPoint, rhs: BidimensionalPoint) -> BidimensionalPoint {
        BidimensionalPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: BidimensionalPoint, rhs: BidimensionalPoint) -> BidimensionalPoint {
        BidimensionalPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (scalar: T, point: BidimensionalPoint) -> BidimensionalPoint {
        BidimensionalPoint(x: scalar * point.x, y: scalar * point.y)
    }
}

extension BidimensionalPoint: VectorState {
    public typealias Scalar = T
}

// MARK: - Monoid (under elementwise addition)

extension BidimensionalPoint: Semigroup {
    public static func combine(_ lhs: BidimensionalPoint, _ rhs: BidimensionalPoint) -> BidimensionalPoint {
        lhs + rhs
    }
}

extension BidimensionalPoint: Monoid {
    public static var identity: BidimensionalPoint { .zero }
}

public func slope<T: ℝ>(point: BidimensionalPoint<T>, anotherPoint: BidimensionalPoint<T>) -> T {
    guard point.x != anotherPoint.x else { return .zero }
    let leftMost = point.x < anotherPoint.x ? point : anotherPoint
    let rightMost = point.x > anotherPoint.x ? point : anotherPoint
    let Δx = rightMost.x - leftMost.x
    let Δy = rightMost.y - leftMost.y

    return Δy / Δx
}
