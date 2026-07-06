// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Math
import XCTest

final class BidimensionalPointMonoidTests: XCTestCase {
    typealias P = BidimensionalPoint<Double>

    func testIdentityIsTheOrigin() {
        XCTAssertEqual(P.identity, P(x: 0, y: 0))
    }

    func testLeftIdentityReturnsValue() {
        let p = P(x: 3, y: -2.5)
        XCTAssertEqual(P.combine(.identity, p), p)
    }

    func testRightIdentityReturnsValue() {
        let p = P(x: 3, y: -2.5)
        XCTAssertEqual(P.combine(p, .identity), p)
    }

    func testCombineMatchesElementwiseAddition() {
        let lhs = P(x: 1, y: 2)
        let rhs = P(x: 4, y: -3)
        XCTAssertEqual(P.combine(lhs, rhs), P(x: 5, y: -1))
    }

    func testAssociativity() {
        let a = P(x: 1, y: 2)
        let b = P(x: 3, y: 4)
        let c = P(x: 5, y: 6)
        XCTAssertEqual(P.combine(P.combine(a, b), c), P.combine(a, P.combine(b, c)))
    }

    func testMConcatOnEmptyArrayReturnsIdentity() {
        let result: P = mconcat([])
        XCTAssertEqual(result, .zero)
    }

    func testMConcatFoldsSequenceThroughCombine() {
        let result: P = mconcat([
            P(x: 1, y: 2),
            P(x: 3, y: 4),
            P(x: 5, y: 6)
        ])
        XCTAssertEqual(result, P(x: 9, y: 12))
    }
}
