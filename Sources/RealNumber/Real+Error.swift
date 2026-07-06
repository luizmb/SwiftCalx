// SPDX-License-Identifier: Apache-2.0

import Foundation

public extension ℝ {
    func error(from expected: Self) -> Self {
        abs(expected - self)
    }
}
