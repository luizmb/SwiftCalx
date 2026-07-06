// SPDX-License-Identifier: Apache-2.0

import Foundation

extension Float: ℝ {
    public func raisedToThePower(of exponent: Self) -> Self {
        powf(self, exponent)
    }

    public static func eⁿ(_ n: Self) -> Self {
        exp(n)
    }
}
