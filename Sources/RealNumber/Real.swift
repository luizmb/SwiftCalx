// SPDX-License-Identifier: Apache-2.0

import Foundation

public typealias Real = ℝ

public protocol ℝ: SignedNumeric, Comparable, Sendable {
    static var epsilon: Self { get }
    static func / (_ a: Self, _ b: Self) -> Self
    var isNaN: Bool { get }
    func raisedToThePower(of exponent: Self) -> Self
    static func random<T: RandomNumberGenerator>(in range: Range<Self>, using generator: inout T) -> Self
    func isMultiple(of number: Self, tolerance: Self) -> Bool
    static var notANumber: Self { get }
    static func eⁿ(_ n: Self) -> Self
    static var e: Self { get }
    var sign: FloatingPointSign { get }
    func squareRoot() -> Self
}

public extension ℝ {
    func cubeRoot() -> Self {
        nRoot(degree: 3)
    }

    func nRoot(degree: Self) -> Self {
        guard self >= 0 || !degree.isMultiple(of: 2) else { return .notANumber }
        return raisedToThePower(of: (1 as Self) / degree)
    }

    func isMultiple(of divisor: Self) -> Bool {
        isMultiple(of: divisor, tolerance: 0)
    }

    static var e: Self { eⁿ(1) }
}

public extension BinaryFloatingPoint where Self: Strideable, Stride == Self {
    func isMultiple(of divisor: Self, tolerance: Self) -> Bool {
        let divisor = divisor == 0 ? divisor + tolerance / 2 : divisor
        guard divisor != 0 else { return false }
        let rem = remainder(dividingBy: divisor)
        let absoluteTolerance: Self = abs(tolerance)
        let rangeWeConsiderEqual = ((0 as Self).advanced(by: -absoluteTolerance) ... (0 as Self).advanced(by: absoluteTolerance))
        return rangeWeConsiderEqual.contains(rem)
    }
}

public extension BinaryFloatingPoint {
    static var epsilon: Self { ulpOfOne }
    static var notANumber: Self { nan }
}
