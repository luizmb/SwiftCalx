// SPDX-License-Identifier: Apache-2.0

import Foundation

extension Decimal: ℝ {
    public static func random<T: RandomNumberGenerator>(in range: Range<Decimal>, using generator: inout T) -> Decimal {
        Decimal(
            Double.random(
                in: Range(
                    uncheckedBounds: (
                        lower: NSDecimalNumber(decimal: range.lowerBound).doubleValue,
                        upper: NSDecimalNumber(decimal: range.upperBound).doubleValue
                    )
                ),
                using: &generator
            )
        )
    }

    public static let epsilon: Decimal = 1e-6
}

public extension Decimal {
    func squareRoot() -> Self {
        nRoot(degree: 2)
    }

    func raisedToThePower(of exponent: Decimal) -> Decimal {
        let result: Double = pow(
            NSDecimalNumber(decimal: self).doubleValue,
            NSDecimalNumber(decimal: exponent).doubleValue
        )
        return NSDecimalNumber(value: result).decimalValue
    }

    static var notANumber: Decimal {
        nan
    }

    func isMultiple(of divisor: Self, tolerance: Self) -> Bool {
        let divisor = divisor == 0 ? divisor + tolerance / 2 : divisor
        guard divisor != 0 else { return false }
        let selfAsDouble = NSDecimalNumber(decimal: self).doubleValue
        let divisorAsDouble = NSDecimalNumber(decimal: divisor).doubleValue
        let rem = selfAsDouble.remainder(dividingBy: divisorAsDouble)
        let absoluteTolerance: Self = abs(tolerance)
        let rangeWeConsiderEqual = ((0 as Self).advanced(by: -absoluteTolerance) ... (0 as Self).advanced(by: absoluteTolerance))
        return rangeWeConsiderEqual.contains(NSDecimalNumber(value: rem).decimalValue)
    }

    static func eⁿ(_ n: Self) -> Self {
        NSDecimalNumber(
            value: exp(
                Double(
                    NSDecimalNumber(decimal: n).doubleValue
                )
            )
        ).decimalValue
    }
}
