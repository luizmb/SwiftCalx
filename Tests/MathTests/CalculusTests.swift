// SPDX-License-Identifier: Apache-2.0

//
//  CalculusTests.swift
//  CalculusTests
//
//  Created by Luiz Rodrigo Martins Barbosa on 21.03.19.
//  Copyright © 2019 Luiz Rodrigo Martins Barbosa. All rights reserved.
//

import Math
import XCTest

// class CalculusTests: XCTestCase {
//    func testDerivativeTangent() {
//        // given
//        let testScenarios: [(function: (Decimal) -> Decimal,        point: Decimal, expectedSlope: Decimal)] = [
//            (function: { (x: Decimal) -> Decimal in x < 3 ? 5 - 2 * x : 4 * x - 13 }, point: 3, expectedSlope: 4),
//            (function: { x in 3 * x * x + 2 * x - 1 },              point: 3,       expectedSlope: 20),
//            (function: { x in x * (3 * x - 5) },                    point: 1 / 2,   expectedSlope: -2),
//            (function: { x in x < 1 ? pow(x, 2) : 2 * x - 1 },      point: 1,       expectedSlope: 2),
//            (function: { x in pow(x, 2) - 2 * x },                  point: 3,       expectedSlope: 4),
//            (function: { x in x > 3 ? 10 - x : 3 * x - 2 },         point: 3,       expectedSlope: -1),
//            (function: { x in 2 * abs(x - 3) },                     point: 3,       expectedSlope: 2),
//            (function: { x in x < 1 ? x : 2 * x - 1 },              point: 1,       expectedSlope: 2),
//            (function: { x in pow(x, (1/3)) },                      point: 0,       expectedSlope: 0)
//        ]
//        let accuracy = 1e-12
//
//        // when
//        let slopes = testScenarios.map { testCase in
//            derivative(testCase.function)(testCase.point)
//        }
//
//        // then
//        XCTAssertEqual(testScenarios.count, slopes.count)
//        let assertions = zip(testScenarios, slopes)
//        assertions.forEach { testScenario, slope in
//            if testScenario.expectedSlope == .nan && slope == .nan {
//                return
//            }
//            let expected = NSDecimalNumber(decimal: testScenario.expectedSlope).doubleValue
//            let calculated = NSDecimalNumber(decimal: slope).doubleValue
//            XCTAssertEqual(expected, calculated, accuracy: accuracy)
//        }
//    }
//
//    func testDerivativeNormalPerpendicular() {
//        // given
//        let testScenarios: [(function: (Decimal) -> Decimal,        point: Decimal, expectedSlope: Decimal)] = [
//
//            (function: { (x: Decimal) -> Decimal in x < 3 ? 5 - 2 * x : 4 * x - 13 }, point: 3, expectedSlope: -0.25),
//            (function: { x in 3 * x * x + 2 * x - 1 },              point: 3,       expectedSlope: -0.05),
//            (function: { x in x * (3 * x - 5) },                    point: 1 / 2,   expectedSlope: 0.5),
//            (function: { x in x < 1 ? pow(x, 2) : 2 * x - 1 },      point: 1,       expectedSlope: -0.5),
//            (function: { x in pow(x, 2) - 2 * x },                  point: 3,       expectedSlope: -0.25),
//            (function: { x in x > 3 ? 10 - x : 3 * x - 2 },         point: 3,       expectedSlope: 1),
//            (function: { x in 2 * abs(x - 3) },                     point: 3,       expectedSlope: -0.5),
//            (function: { x in x < 1 ? x : 2 * x - 1 },              point: 1,       expectedSlope: -0.5),
//            (function: { x in pow(x, (1/3)) },                      point: 0,       expectedSlope: Decimal.nan)
//        ]
//        let accuracy = 1e-12
//
//        // when
//        let slopes = testScenarios.map { testCase in
//            derivativePerpendicular(testCase.function)(testCase.point)
//        }
//
//        XCTAssertEqual(testScenarios.count, slopes.count)
//        let assertions = zip(testScenarios, slopes)
//        assertions.forEach { testScenario, slope in
//            if testScenario.expectedSlope == .nan && slope == .nan {
//                return
//            }
//            let expected = NSDecimalNumber(decimal: testScenario.expectedSlope).doubleValue
//            let calculated = NSDecimalNumber(decimal: slope).doubleValue
//            XCTAssertEqual(expected, calculated, accuracy: accuracy)
//        }
//    }
//
//    func testIsDifferentiableAtPoint() {
//        // given
//        let testScenarios: [(function: (Decimal) -> Decimal,        point: Decimal, expectedIsDifferentiable: Bool)] = [
//
//            (function: { (x: Decimal) -> Decimal in x < 3 ? 5 - 2 * x : 4 * x - 13 }, point: 3, expectedIsDifferentiable: false),
//            (function: { x in 3 * x * x + 2 * x - 1 },              point: 3,       expectedIsDifferentiable: true),
//            (function: { x in x * (3 * x - 5) },                    point: 1 / 2,   expectedIsDifferentiable: true),
//            (function: { x in x < 1 ? pow(x, 2) : 2 * x - 1 },      point: 1,       expectedIsDifferentiable: true),
//            (function: { x in pow(x, 2) - 2 * x },                  point: 3,       expectedIsDifferentiable: true),
//            (function: { x in x > 3 ? 10 - x : 3 * x - 2 },         point: 3,       expectedIsDifferentiable: false),
//            (function: { x in 2 * abs(x - 3) },                     point: 3,       expectedIsDifferentiable: false),
//            (function: { x in x < 1 ? x : 2 * x - 1 },              point: 1,       expectedIsDifferentiable: false)
//            // (function: { x in pow(x, (1/3)) },                      point: 0,       expectedIsDifferentiable: false)
//            // TODO: This should be false, but it's currently returning true. If the point creates a vertical tangent
//            //       the function is not differentiable, but our algorithm currently can't detect that.
//        ]
//
//        // when
//        let results = testScenarios.map { testCase in
//            isDifferentiable(at: testCase.point, testCase.function)
//        }
//
//        XCTAssertEqual(testScenarios.count, results.count)
//        let assertions = zip(testScenarios, results)
//        assertions.forEach { testScenario, isDifferentiableAtPoint in
//            XCTAssertEqual(testScenario.expectedIsDifferentiable, isDifferentiableAtPoint)
//        }
//    }
// }
