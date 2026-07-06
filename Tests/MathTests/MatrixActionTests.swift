// SPDX-License-Identifier: Apache-2.0

import Math
import MathOperators
import XCTest

final class MatrixActionTests: XCTestCase {
    func testActionsZeroCountReturnsInitialOnly() {
        let A = Matrix<Double>.identity(size: 2)
        let trajectory = A.actions(on: [3, 4], count: 0)
        XCTAssertEqual(trajectory.count, 1)
        XCTAssertEqual(trajectory[0], [3, 4])
    }

    func testActionsCountOneIsInitialPlusOneApplication() {
        let A = Matrix<Double>(rows: 2, columns: 2, storage: [2, 0, 0, 3])
        let trajectory = A.actions(on: [1, 1], count: 1)
        XCTAssertEqual(trajectory.count, 2)
        XCTAssertEqual(trajectory[0], [1, 1])
        XCTAssertEqual(trajectory[1], [2, 3])
    }

    func testActionsMatchesRepeatedApply() {
        let A = Matrix<Double>(rows: 2, columns: 2, storage: [2, 0, 0, 3])
        let trajectory = A.actions(on: [1, 1], count: 4)
        XCTAssertEqual(trajectory.count, 5)
        XCTAssertEqual(trajectory[2], [4, 9]) // A² · [1,1]
        XCTAssertEqual(trajectory[3], [8, 27]) // A³ · [1,1]
        XCTAssertEqual(trajectory[4], [16, 81]) // A⁴ · [1,1]
    }

    func testActionsMatchesMatrixPowerTimesVector() {
        // A = [[1,1],[0,1]] generates the Fibonacci-like upper triangular family.
        // Aⁿ · [a, b] = [a + n·b, b]. Walking the action should agree.
        let A = Matrix<Double>(rows: 2, columns: 2, storage: [1, 1, 0, 1])
        let initial = [10.0, 3.0]
        let trajectory = A.actions(on: initial, count: 5)
        for n in 0 ... 5 {
            let expected = [10.0 + Double(n) * 3.0, 3.0]
            XCTAssertEqual(trajectory[n], expected, "step \(n)")
        }
    }

    func testActionsLeavesInitialIntactAtIndexZero() {
        let A = Matrix<Double>(rows: 2, columns: 2, storage: [5, 7, 11, 13])
        let initial = [1.5, -2.5]
        let trajectory = A.actions(on: initial, count: 10)
        XCTAssertEqual(trajectory.first, initial)
    }
}
