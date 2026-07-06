// SPDX-License-Identifier: Apache-2.0

import Foundation

extension Float: ℝ {
    public func raisedToThePower(of exponent: Self) -> Self {
        powf(self, exponent)
    }

    public static func eⁿ(_ n: Self) -> Self {
        // Round-trip through Double: Android's NDK math.h exposes only exp(Double),
        // not a Float overload. Double(exp) is identical and portable everywhere.
        Float(exp(Double(n)))
    }
}
