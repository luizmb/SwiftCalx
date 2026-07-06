// SPDX-License-Identifier: Apache-2.0

import Foundation

public extension ℝ {
    /// Returns the negated version of itself, meaning the sign is flipped.
    var negated: Self {
        var copy = self
        copy.negate()
        return copy
    }

    func useSign(from value: Self) -> Self {
        (value < 0) != (self < 0) ? negated : self
    }
}
