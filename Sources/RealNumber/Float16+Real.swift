// SPDX-License-Identifier: Apache-2.0

import Foundation

#if !((os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64))
    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    extension Float16: ℝ {
        public func raisedToThePower(of exponent: Float16) -> Float16 {
            Float16(powf(Float(self), Float(exponent)))
        }

        public static func eⁿ(_ n: Self) -> Self {
            Float16(exp(Float(n)))
        }
    }
#endif
