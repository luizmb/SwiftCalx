// SPDX-License-Identifier: Apache-2.0

@testable import Calculus
@testable import Math
import XCTest

final class SimpsonWeightedAverageTests: XCTestCase {
    func testScalarConcreteCase() {
        let result = SimpsonWeightedAverage.calculate(1.0, 2.0, 3.0, 4.0)
        XCTAssertEqual(result, (1.0 + 2 * 2.0 + 2 * 3.0 + 4.0) / 6, accuracy: 1e-12)
    }

    func testAllZeros() {
        XCTAssertEqual(SimpsonWeightedAverage.calculate(0.0, 0.0, 0.0, 0.0), 0)
    }

    func testAllSameValueReturnsThatValue() {
        // (v + 2v + 2v + v) / 6 = 6v / 6 = v.
        let v = 7.5
        XCTAssertEqual(SimpsonWeightedAverage.calculate(v, v, v, v), v, accuracy: 1e-12)
    }

    func testWeightingHasSimpsonsCoefficients() {
        // Each argument's contribution is (its coefficient) / 6.
        XCTAssertEqual(SimpsonWeightedAverage.calculate(1.0, 0.0, 0.0, 0.0), 1.0 / 6, accuracy: 1e-12)
        XCTAssertEqual(SimpsonWeightedAverage.calculate(0.0, 1.0, 0.0, 0.0), 2.0 / 6, accuracy: 1e-12)
        XCTAssertEqual(SimpsonWeightedAverage.calculate(0.0, 0.0, 1.0, 0.0), 2.0 / 6, accuracy: 1e-12)
        XCTAssertEqual(SimpsonWeightedAverage.calculate(0.0, 0.0, 0.0, 1.0), 1.0 / 6, accuracy: 1e-12)
    }

    func testVectorVariant() {
        let result = SimpsonWeightedAverage.calculate([1.0, 0], [0, 1.0], [0, 0], [0, 0])
        XCTAssertEqual(result[0], 1.0 / 6, accuracy: 1e-12)
        XCTAssertEqual(result[1], 2.0 / 6, accuracy: 1e-12)
    }
}
