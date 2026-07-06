// SPDX-License-Identifier: Apache-2.0

import Foundation
import Math
import RealNumber

prefix operator √
prefix operator ∛

public prefix func √ <T: ℝ>(_ value: T) -> T {
    value.squareRoot()
}

public prefix func ∛ <T: ℝ>(_ value: T) -> T {
    value.cubeRoot()
}
