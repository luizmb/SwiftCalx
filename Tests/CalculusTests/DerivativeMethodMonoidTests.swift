// SPDX-License-Identifier: Apache-2.0

import Calculus
import CoreFP
import Math
import XCTest

final class DerivativeMethodMonoidTests: XCTestCase {
    private let stencil = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .adaptative)
    private let f = Fn<Double> { x in x * x * x } // f(x) = x³

    // MARK: - Direct identity / then API

    func testIdentityKeepsFunctionUnchanged() {
        let id = DerivativeMethod<Double>.identity
        XCTAssertEqual(id.deriving(f)(2.0), f(2.0))
    }

    func testIdentityHasOrderZero() {
        XCTAssertEqual(DerivativeMethod<Double>.identity.order, 0)
    }

    func testThenComposesLeftToRightAndAddsOrders() {
        let composed = stencil.then(stencil)
        XCTAssertEqual(composed.order, 2)
    }

    func testThenLeftIdentityActsLikeRhs() {
        let composed = DerivativeMethod<Double>.identity.then(stencil)
        XCTAssertEqual(composed.order, stencil.order)
        XCTAssertEqual(composed.deriving(f)(2.0), stencil.deriving(f)(2.0), accuracy: 1e-9)
    }

    func testThenRightIdentityActsLikeLhs() {
        let composed = stencil.then(.identity)
        XCTAssertEqual(composed.order, stencil.order)
        XCTAssertEqual(composed.deriving(f)(2.0), stencil.deriving(f)(2.0), accuracy: 1e-9)
    }

    func testComposedTwiceApproximatesSecondDerivative() {
        // f(x) = x³, f''(x) = 6x. At x = 2, f''(2) = 12.
        let composed = stencil.then(stencil)
        XCTAssertEqual(
            composed.deriving(f)(2.0),
            12.0,
            accuracy: 1.0,
            "Chained 1st-order stencils lose precision; 1.0 is the documented tolerance band"
        )
    }

    // MARK: - Direct Monoid conformance

    func testCombineMatchesThen() {
        let combined = DerivativeMethod<Double>.combine(stencil, stencil)
        XCTAssertEqual(combined.order, stencil.then(stencil).order)
        XCTAssertEqual(
            combined.deriving(f)(2.0),
            stencil.then(stencil).deriving(f)(2.0),
            accuracy: 1e-12
        )
    }

    func testMConcatOnEmptyArrayReturnsIdentity() {
        let result: DerivativeMethod<Double> = mconcat([])
        XCTAssertEqual(result.order, 0)
        XCTAssertEqual(result.deriving(f)(2.0), f(2.0))
    }

    func testMConcatChainsStages() {
        let stages = Array(repeating: stencil, count: 3)
        let composed: DerivativeMethod<Double> = mconcat(stages)
        XCTAssertEqual(composed.order, 3)
    }

    func testCombineIsAssociative() {
        let s = stencil
        let lhs = DerivativeMethod<Double>.combine(DerivativeMethod<Double>.combine(s, s), s)
        let rhs = DerivativeMethod<Double>.combine(s, DerivativeMethod<Double>.combine(s, s))
        XCTAssertEqual(lhs.order, rhs.order)
        XCTAssertEqual(lhs.deriving(f)(2.0), rhs.deriving(f)(2.0), accuracy: 1e-6)
    }
}
