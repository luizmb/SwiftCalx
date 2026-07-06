// SPDX-License-Identifier: Apache-2.0

import Foundation

extension Double: ℝ {
    public func raisedToThePower(of exponent: Self) -> Self {
        pow(self, exponent)
    }

    public static func eⁿ(_ n: Self) -> Self {
        exp(n)
    }
}
