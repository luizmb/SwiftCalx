// SPDX-License-Identifier: Apache-2.0

@testable import Calculus
@testable import Math
import XCTest

final class TaylorTests: XCTestCase {
    private let tolerance = 1e-10

    func testExpOfZeroIsIdentity() {
        let result = Taylor.exponential(of: Matrix<Double>.zero(size: 4))
        assertEqual(result, Matrix<Double>.identity(size: 4))
    }

    func testExpOfSmallDiagonalMatrix() {
        // For ‖A‖ small, Taylor alone is fine — no scaling needed.
        let A = Matrix<Double>(rows: 2, columns: 2, storage: [
            -0.1, 0,
            0, -0.05
        ])
        let result = Taylor.exponential(of: A)
        let expected = Matrix<Double>(rows: 2, columns: 2, storage: [
            exp(-0.1), 0,
            0, exp(-0.05)
        ])
        assertEqual(result, expected)
    }

    func testExpOfNilpotentMatrix() {
        // N² = 0 ⇒ e^N = I + N exactly.
        let N = Matrix<Double>(rows: 3, columns: 3, storage: [
            0, 1, 0,
            0, 0, 0,
            0, 0, 0
        ])
        let result = Taylor.exponential(of: N)
        let expected = Matrix<Double>.identity(size: 3) + N
        assertEqual(result, expected)
    }

    func testConvergedTrueWhenAllRatiosTiny() {
        let sum = Matrix<Double>.identity(size: 2)
        let term = 1e-15 * Matrix<Double>.identity(size: 2)
        XCTAssertTrue(Taylor.converged(term: term, sum: sum, tolerance: 1e-10))
    }

    func testConvergedFalseWhenAnyRatioAboveTolerance() {
        let sum = Matrix<Double>.identity(size: 2)
        let term = 1e-5 * Matrix<Double>.identity(size: 2)
        XCTAssertFalse(Taylor.converged(term: term, sum: sum, tolerance: 1e-10))
    }

    func testConvergedTrueOnTinyNegativeRatios() {
        // The convergence check must use abs() — otherwise a tiny negative term/sum
        // ratio (which is "less than tolerance") would be misread as "not yet converged".
        let sum = Matrix<Double>(rows: 1, columns: 1, storage: [1])
        let term = Matrix<Double>(rows: 1, columns: 1, storage: [-1e-15])
        XCTAssertTrue(Taylor.converged(term: term, sum: sum, tolerance: 1e-10))
    }

    func testConvergedFalseOnLargeNegativeRatios() {
        // Without abs(), -0.5 < 1e-10 would be (incorrectly) treated as converged.
        let sum = Matrix<Double>(rows: 1, columns: 1, storage: [1])
        let term = Matrix<Double>(rows: 1, columns: 1, storage: [-0.5])
        XCTAssertFalse(Taylor.converged(term: term, sum: sum, tolerance: 1e-10))
    }

    private func assertEqual(_ lhs: Matrix<Double>, _ rhs: Matrix<Double>, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.rows, rhs.rows, file: file, line: line)
        XCTAssertEqual(lhs.columns, rhs.columns, file: file, line: line)
        for (l, r) in zip(lhs.storage, rhs.storage) {
            XCTAssertEqual(l, r, accuracy: tolerance, file: file, line: line)
        }
    }
}
