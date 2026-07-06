// SPDX-License-Identifier: Apache-2.0

import Foundation

#if (arch(i386) || arch(x86_64)) && !os(Windows) && !os(Android)
    extension Float80: ℝ {
        public func raisedToThePower(of exponent: Self) -> Self {
            powl(self, exponent)
        }

        public static func eⁿ(_ n: Self) -> Self {
            exp(n)
        }
    }
#endif
