// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Math
import XCTest

final class TridimensionalPointMonoidTests: XCTestCase {
    typealias P = TridimensionalPoint<Double>

    func testIdentityIsTheOrigin() {
        XCTAssertEqual(P.identity, P(x: 0, y: 0, z: 0))
    }

    func testCombineMatchesElementwiseAddition() {
        let lhs = P(x: 1, y: 2, z: 3)
        let rhs = P(x: 4, y: 5, z: 6)
        XCTAssertEqual(P.combine(lhs, rhs), P(x: 5, y: 7, z: 9))
    }

    func testMConcatFoldsSequence() {
        let result: P = mconcat([
            P(x: 1, y: 2, z: 3),
            P(x: 4, y: 5, z: 6),
            P(x: 7, y: 8, z: 9)
        ])
        XCTAssertEqual(result, P(x: 12, y: 15, z: 18))
    }
}
