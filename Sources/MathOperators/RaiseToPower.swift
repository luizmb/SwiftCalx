// SPDX-License-Identifier: Apache-2.0

import Foundation
import RealNumber

precedencegroup ExponentPrecedence {
    associativity: left
    higherThan: MultiplicationPrecedence
    lowerThan: BitwiseShiftPrecedence
}

// Hey, unfortunately we can't use ^ because Swift defines it with AdditionPrecedence,
// the same as + and - operators.
// https://github.com/apple/swift/blob/main/stdlib/public/core/Policy.swift#L485
// That, combined with a left associativity, means that the following formula:
// ```
// 5 + 9 ^ 2
// ```
// would first sum 5 + 9, resulting in 14, and then raised that to the power of 2, giving 196.
// In real Math, we know that exponentiation has precedence over addition and multiplication,
// which means we should first raise 9 to the power of 2, resulting in 81, and then plus 5,
// giving 86, which is the correct result for this formula. If you drop a multiplication in
// that, it would mess even more the result, because of the precedence.
//
// So we need to define a brand new operator, and Swift limits the options here. Much better
// options are forbidden, unfortunately.
// ^^ seems to be the best option here, and `5 + 9 ^^ 2` should give us the right result.
infix operator ^^: ExponentPrecedence

public func ^^ <N: ℝ>(_ base: N, exp: N) -> N {
    base.raisedToThePower(of: exp)
}
