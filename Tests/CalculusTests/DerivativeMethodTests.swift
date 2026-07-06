// SPDX-License-Identifier: Apache-2.0

@testable import Calculus
import Foundation
import RealNumber
import XCTest

final class DerivativeMethodTests: XCTestCase {
    // MARK: - Central stencils, first derivative

    func testCentralStencilThreePointFirstDerivativeOnSine() {
        let sinFn = Fn<Double> { sin($0) }
        let method = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.01))
        let cosApprox = method.deriving(sinFn)
        for x in stride(from: 0.0, through: 2 * .pi, by: .pi / 4) {
            XCTAssertEqual(cosApprox(x), cos(x), accuracy: 1e-4, "at x=\(x)")
        }
    }

    func testCentralStencilFivePointFirstDerivativeBeatsThreePoint() {
        let sinFn = Fn<Double> { sin($0) }
        let three = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.1))
        let five = DerivativeMethod<Double>.CentralStencil.fivePoint(order: 1, step: .constant(0.1))
        let x = 1.0
        let truth = cos(x)
        let threeError = abs(three.deriving(sinFn)(x) - truth)
        let fiveError = abs(five.deriving(sinFn)(x) - truth)
        XCTAssertLessThan(fiveError, threeError / 100, "5-point should be ≥100× more accurate than 3-point at h=0.1")
    }

    // MARK: - Central stencils, second derivative (the headline use case)

    func testCentralStencilThreePointSecondDerivativeOnSine() {
        // f(x) = sin(x), f''(x) = -sin(x).
        let sinFn = Fn<Double> { sin($0) }
        let method = DerivativeMethod<Double>.CentralStencil.threePoint(order: 2, step: .constant(0.01))
        let secondDeriv = method.deriving(sinFn)
        for x in stride(from: 0.0, through: 2 * .pi, by: .pi / 4) {
            XCTAssertEqual(secondDeriv(x), -sin(x), accuracy: 1e-4, "f''(\(x)) ≈ -sin(\(x))")
        }
    }

    func testCentralStencilFivePointSecondDerivativeIsMoreAccurate() {
        let cosFn = Fn<Double> { cos($0) }
        let three = DerivativeMethod<Double>.CentralStencil.threePoint(order: 2, step: .constant(0.1))
        let five = DerivativeMethod<Double>.CentralStencil.fivePoint(order: 2, step: .constant(0.1))
        let x = 1.0
        let truth = -cos(x) // d²/dx² cos(x) = -cos(x)
        let threeError = abs(three.deriving(cosFn)(x) - truth)
        let fiveError = abs(five.deriving(cosFn)(x) - truth)
        XCTAssertLessThan(fiveError, threeError / 10, "5-point second derivative should be much more accurate")
    }

    func testCentralStencilFivePointFourthDerivativeOnSine() {
        // f(x) = sin(x), f⁽⁴⁾(x) = sin(x).
        let sinFn = Fn<Double> { sin($0) }
        let method = DerivativeMethod<Double>.CentralStencil.fivePoint(order: 4, step: .constant(0.05))
        let fourthDeriv = method.deriving(sinFn)
        XCTAssertEqual(fourthDeriv(1.0), sin(1.0), accuracy: 1e-3)
    }

    func testRequestingUnsupportedOrderReturnsNaN() {
        // 3-point central can't do order 3 (needs 5+ points).
        let method = DerivativeMethod<Double>.CentralStencil.threePoint(order: 3, step: .constant(0.1))
        XCTAssertEqual(method.order, 3)
        let nanFn = method.deriving(Fn<Double> { _ in 1.0 })
        XCTAssertTrue(nanFn(0).isNaN, "unsupported order should yield NaN, not crash")
    }

    // MARK: - One-sided stencils

    func testForwardStencilTwoPoint() {
        let sqFn = Fn<Double> { $0 * $0 } // f'(x) = 2x
        let method = DerivativeMethod<Double>.ForwardStencil.twoPoint(step: .constant(1e-6))
        XCTAssertEqual(method.deriving(sqFn)(3), 6.0, accuracy: 1e-4)
    }

    func testForwardStencilThreePointSecondDerivative() {
        let cubeFn = Fn<Double> { $0 * $0 * $0 } // f''(x) = 6x
        let method = DerivativeMethod<Double>.ForwardStencil.threePoint(order: 2, step: .constant(0.001))
        XCTAssertEqual(method.deriving(cubeFn)(2), 12.0, accuracy: 1e-2)
    }

    func testBackwardStencilTwoPoint() {
        let sqFn = Fn<Double> { $0 * $0 }
        let method = DerivativeMethod<Double>.BackwardStencil.twoPoint(step: .constant(1e-6))
        XCTAssertEqual(method.deriving(sqFn)(3), 6.0, accuracy: 1e-4)
    }

    // MARK: - Richardson extrapolation

    func testRichardsonImprovesAccuracy() {
        let sinFn = Fn<Double> { sin($0) }
        let coarse = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.1))
        let fine = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.05))
        let extrapolated = DerivativeMethod<Double>.richardsonExtrapolation(
            coarse: coarse, fine: fine, leadingOrder: 2
        )
        let x = 1.0
        let truth = cos(x)
        let coarseError = abs(coarse.deriving(sinFn)(x) - truth)
        let extrapolatedError = abs(extrapolated.deriving(sinFn)(x) - truth)
        XCTAssertLessThan(extrapolatedError, coarseError / 10, "Richardson should kill the O(h²) error term")
    }

    // MARK: - Compose.repeated

    func testComposeRepeatedTwiceMatchesSecondDerivativeRoughly() {
        // Applying a first-derivative method twice approximates the second derivative —
        // with worse accuracy than a direct second-derivative formula, but close enough.
        let sinFn = Fn<Double> { sin($0) }
        let first = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.01))
        let repeatedTwice = DerivativeMethod<Double>.Compose.repeated(first, times: 2)
        XCTAssertEqual(repeatedTwice.order, 2)
        XCTAssertEqual(repeatedTwice.deriving(sinFn)(1.0), -sin(1.0), accuracy: 1e-3)
    }

    func testComposeRepeatedZeroTimesIsIdentity() {
        let method = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.01))
        let zero = DerivativeMethod<Double>.Compose.repeated(method, times: 0)
        XCTAssertEqual(zero.order, 0)
        let sqFn = Fn<Double> { $0 * $0 }
        XCTAssertEqual(zero.deriving(sqFn)(3), 9.0, "repeated 0 times is the identity")
    }

    // MARK: - Fornberg-driven custom stencils

    func testFornbergMatchesHardcodedThreePointFirstDerivative() {
        // Fornberg-generated 3-point central order-1 should equal the hardcoded version.
        let sinFn = Fn<Double> { sin($0) }
        let hardcoded = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.05))
        let fornberg = DerivativeMethod<Double>.fornbergCentralStencil(points: 3, order: 1, step: .constant(0.05))
        for x in stride(from: -1.0, through: 1.0, by: 0.25) {
            XCTAssertEqual(hardcoded.deriving(sinFn)(x), fornberg.deriving(sinFn)(x), accuracy: 1e-12)
        }
    }

    func testFornbergMatchesHardcodedFivePointSecondDerivative() {
        let cosFn = Fn<Double> { cos($0) }
        let hardcoded = DerivativeMethod<Double>.CentralStencil.fivePoint(order: 2, step: .constant(0.05))
        let fornberg = DerivativeMethod<Double>.fornbergCentralStencil(points: 5, order: 2, step: .constant(0.05))
        for x in stride(from: -1.0, through: 1.0, by: 0.25) {
            XCTAssertEqual(hardcoded.deriving(cosFn)(x), fornberg.deriving(cosFn)(x), accuracy: 1e-12)
        }
    }

    func testFornbergSevenPointThirdDerivativeOnSine() {
        // f(x) = sin(x), f'''(x) = -cos(x). Seven-point stencil for third derivative —
        // tolerance ~1e-6 reflects the working precision: h=0.05 raised to the 3rd power
        // is 1.25e-4 in the denominator, amplifying any roundoff in the numerator.
        let sinFn = Fn<Double> { sin($0) }
        let method = DerivativeMethod<Double>.fornbergCentralStencil(points: 7, order: 3, step: .constant(0.05))
        XCTAssertEqual(method.deriving(sinFn)(1.0), -cos(1.0), accuracy: 1e-6)
    }

    func testFornbergRejectsInvalidConfiguration() {
        // Even number of points (non-symmetric around 0 with our convention).
        let bad = DerivativeMethod<Double>.fornbergCentralStencil(points: 4, order: 1, step: .constant(0.1))
        XCTAssertTrue(bad.deriving(Fn { _ in 1.0 })(0).isNaN)
        // Order >= points.
        let bad2 = DerivativeMethod<Double>.fornbergCentralStencil(points: 3, order: 3, step: .constant(0.1))
        XCTAssertTrue(bad2.deriving(Fn { _ in 1.0 })(0).isNaN)
    }

    // MARK: - Witness pattern: user-defined methods

    func testUserDefinedMethodViaCustomFactory() {
        // Demonstrate the extension point: a downstream consumer can invent its own method
        // without modifying this library. Here, a contrived "always returns 7" method.
        let method = DerivativeMethod<Double>.custom(order: 1) { _ in
            Fn { _ in 7.0 }
        }
        XCTAssertEqual(method.deriving(Fn<Double> { $0 })(42.0), 7.0)
    }
}
