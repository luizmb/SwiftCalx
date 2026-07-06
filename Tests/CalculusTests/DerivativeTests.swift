// SPDX-License-Identifier: Apache-2.0

@testable import Calculus
import Foundation
import MathOperators
import RealNumber
import XCTest

class DerivativeTests: XCTestCase {
    func testDerivativeTangent() {
        typealias T = Double
        let testScenarios: [(function: Fn<T>, point: T, expectedSlope: T)] = [
            (function: Fn { x in .e ^^ x }, point: -1, expectedSlope: .e ^^ -1),
            (function: Fn { x in .e ^^ x }, point: 0, expectedSlope: .e ^^ 0),
            (function: Fn { x in .e ^^ x }, point: 1, expectedSlope: .e ^^ 1),
            (function: Fn { x in .e ^^ x }, point: 2, expectedSlope: .e ^^ 2),
            (function: Fn { x in .e ^^ x }, point: 3, expectedSlope: .e ^^ 3),
            (function: Fn { x in .e ^^ x }, point: 4, expectedSlope: .e ^^ 4),
            (function: Fn { x in 6 * x ^^ 3 - 9 * x + 4 }, point: -1, expectedSlope: 18 * (-1 ^^ 2) - 9),
            (function: Fn { x in 6 * x ^^ 3 - 9 * x + 4 }, point: 0, expectedSlope: 18 * 0 ^^ 2 - 9),
            (function: Fn { x in 6 * x ^^ 3 - 9 * x + 4 }, point: 1, expectedSlope: 18 * 1 ^^ 2 - 9),
            (function: Fn { x in 2 * x ^^ 4 - 10 * x ^^ 2 + 13 * x }, point: -10, expectedSlope: 8 * (-10 ^^ 3) - 20 * (-10) + 13),
            (function: Fn { x in 2 * x ^^ 4 - 10 * x ^^ 2 + 13 * x }, point: 0, expectedSlope: 8 * 0 ^^ 3 - 20 * 0 + 13),
            (function: Fn { x in 2 * x ^^ 4 - 10 * x ^^ 2 + 13 * x }, point: 10, expectedSlope: 8 * 10 ^^ 3 - 20 * 10 + 13),
            (function: Fn { x in 4 * x ^^ 7 - 3 * x ^^ (-7) + 9 * x }, point: -1, expectedSlope: 28 * (-1) ^^ 6 + 21 * (-1) ^^ (-8) + 9),
            (function: Fn { x in 4 * x ^^ 7 - 3 * x ^^ (-7) + 9 * x }, point: 0, expectedSlope: 28 * 0 ^^ 6 + 21 * 0 ^^ (-8) + 9),
            (function: Fn { x in 4 * x ^^ 7 - 3 * x ^^ (-7) + 9 * x }, point: 1, expectedSlope: 28 * 1 ^^ 6 + 21 * 1 ^^ (-8) + 9),
            (function: Fn { x in 3 * x * x + 2 * x - 1 }, point: 3, expectedSlope: 20),
            (function: Fn { x in x * (3 * x - 5) }, point: 1 / 2, expectedSlope: -2),
            (function: Fn { x in x < 1 ? pow(x, 2) : 2 * x - 1 }, point: 1, expectedSlope: 2),
            (function: Fn { x in pow(x, 2) - 2 * x }, point: 3, expectedSlope: 4),
            (function: Fn { x in x < 3 ? 5 - 2 * x : 4 * x - 13 }, point: 3, expectedSlope: 4),
            (function: Fn { x in x > 3 ? 10 - x : 3 * x - 2 }, point: 3, expectedSlope: -1),
            (function: Fn { x in 2 * abs(x - 3) }, point: 3, expectedSlope: 2),
            (function: Fn { x in x < 1 ? x : 2 * x - 1 }, point: 1, expectedSlope: 2),
            (function: Fn { x in abs(x) }, point: -1, expectedSlope: -1),
            (function: Fn { x in abs(x) }, point: 1, expectedSlope: 1),
        ]
        let accuracy: T = 1e-3

        let slopes = testScenarios.map { testCase in
            testCase.function.differentiate(
                method: .ForwardStencil.twoPoint(step: .epsilonSquareRoot)
            )(x: testCase.point)
        }

        XCTAssertEqual(testScenarios.count, slopes.count)
        for (testScenario, slope) in zip(testScenarios, slopes) {
            if testScenario.expectedSlope.isNaN || testScenario.expectedSlope.isInfinite,
               slope.isNaN || slope.isInfinite {
                continue
            }
            XCTAssertEqual(testScenario.expectedSlope, slope, accuracy: accuracy)
        }
    }

    func testDerivativeNormalPerpendicular() {
        let testScenarios: [(function: Fn<Double>, point: Double, expectedSlope: Double)] = [
            (function: Fn { x in x < 3 ? 5 - 2 * x : 4 * x - 13 }, point: 3, expectedSlope: -0.25),
            (function: Fn { x in 3 * x * x + 2 * x - 1 }, point: 3, expectedSlope: -0.05),
            (function: Fn { x in x * (3 * x - 5) }, point: 1 / 2, expectedSlope: 0.5),
            (function: Fn { x in x < 1 ? pow(x, 2) : 2 * x - 1 }, point: 1, expectedSlope: -0.5),
            (function: Fn { x in pow(x, 2) - 2 * x }, point: 3, expectedSlope: -0.25),
            (function: Fn { x in x > 3 ? 10 - x : 3 * x - 2 }, point: 3, expectedSlope: 1),
            (function: Fn { x in 2 * abs(x - 3) }, point: 3, expectedSlope: -0.5),
            (function: Fn { x in x < 1 ? x : 2 * x - 1 }, point: 1, expectedSlope: -0.5),
            (function: Fn { x in pow(x, (1 / 3)) }, point: 0, expectedSlope: Double.nan)
        ]
        let accuracy = 1e-7

        let slopes = testScenarios.map { testCase in
            testCase.function
                .differentiate(method: .ForwardStencil.twoPoint(step: .adaptative))
                .perpendicular()(testCase.point)
        }

        XCTAssertEqual(testScenarios.count, slopes.count)
        zip(testScenarios, slopes).forEach { testScenario, slope in
            if testScenario.expectedSlope.isNaN, slope.isNaN { return }
            XCTAssertEqual(testScenario.expectedSlope, slope, accuracy: accuracy)
        }
    }

    func testIsDifferentiableAtPoint() {
        let testScenarios: [(function: Fn<Double>, point: Double, expectedIsDifferentiable: Bool)] = [
            (function: Fn { x in x < 3 ? 5 - 2 * x : 4 * x - 13 }, point: 3, expectedIsDifferentiable: false),
            (function: Fn { x in 3 * x * x + 2 * x - 1 }, point: 3, expectedIsDifferentiable: true),
            (function: Fn { x in x * (3 * x - 5) }, point: 1 / 2, expectedIsDifferentiable: true),
            (function: Fn { x in x < 1 ? pow(x, 2) : 2 * x - 1 }, point: 1, expectedIsDifferentiable: true),
            (function: Fn { x in pow(x, 2) - 2 * x }, point: 3, expectedIsDifferentiable: true),
            (function: Fn { x in x > 3 ? 10 - x : 3 * x - 2 }, point: 3, expectedIsDifferentiable: false),
            (function: Fn { x in 2 * abs(x - 3) }, point: 3, expectedIsDifferentiable: false),
            (function: Fn { x in x < 1 ? x : 2 * x - 1 }, point: 1, expectedIsDifferentiable: false),
            (function: Fn { x in pow(x, (1 / 3)) }, point: 0, expectedIsDifferentiable: false)
        ]

        let results = testScenarios.map { testCase in
            testCase.function
                .differentiate(method: .ForwardStencil.twoPoint(step: .adaptative))
                .isDifferentiable(at: testCase.point, h: 0.0001)
        }

        XCTAssertEqual(testScenarios.count, results.count)
        for (testScenario, isDifferentiableAtPoint) in zip(testScenarios, results) {
            XCTAssertEqual(testScenario.expectedIsDifferentiable, isDifferentiableAtPoint)
        }
    }
}
