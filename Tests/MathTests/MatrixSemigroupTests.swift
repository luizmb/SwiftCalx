// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Math
import MathOperators
import XCTest

final class MatrixSemigroupTests: XCTestCase {
    // MARK: - Sum (additive semigroup)

    func testSumCombineMatchesElementwiseAddition() {
        let lhs = Matrix<Double>.Sum(Matrix(rows: 2, columns: 2, storage: [1, 2, 3, 4]))
        let rhs = Matrix<Double>.Sum(Matrix(rows: 2, columns: 2, storage: [5, 6, 7, 8]))
        XCTAssertEqual(
            Matrix<Double>.Sum.combine(lhs, rhs).rawValue,
            lhs.rawValue + rhs.rawValue
        )
    }

    func testSumAssociativity() {
        let A = Matrix<Double>.Sum(Matrix(rows: 1, columns: 2, storage: [1, 2]))
        let B = Matrix<Double>.Sum(Matrix(rows: 1, columns: 2, storage: [3, 4]))
        let C = Matrix<Double>.Sum(Matrix(rows: 1, columns: 2, storage: [5, 6]))
        XCTAssertEqual(
            Matrix<Double>.Sum.combine(Matrix<Double>.Sum.combine(A, B), C).rawValue,
            Matrix<Double>.Sum.combine(A, Matrix<Double>.Sum.combine(B, C)).rawValue
        )
    }

    func testSumSconcatFoldsThroughCombine() {
        let matrices: [Matrix<Double>.Sum] = [
            Matrix<Double>.Sum(Matrix(rows: 1, columns: 2, storage: [1, 2])),
            Matrix<Double>.Sum(Matrix(rows: 1, columns: 2, storage: [3, 4])),
            Matrix<Double>.Sum(Matrix(rows: 1, columns: 2, storage: [5, 6]))
        ]
        let result = sconcat(matrices[0], Array(matrices.dropFirst()))
        XCTAssertEqual(result.rawValue, Matrix(rows: 1, columns: 2, storage: [9, 12]))
    }

    // MARK: - Product (multiplicative semigroup)

    func testProductCombineMatchesMatrixMultiplication() {
        let A = Matrix<Double>(rows: 2, columns: 2, storage: [1, 2, 3, 4])
        let B = Matrix<Double>(rows: 2, columns: 2, storage: [5, 6, 7, 8])
        XCTAssertEqual(
            Matrix<Double>.Product.combine(
                Matrix<Double>.Product(A),
                Matrix<Double>.Product(B)
            ).rawValue,
            A * B
        )
    }

    func testProductAssociativity() {
        let a = Matrix<Double>(rows: 2, columns: 2, storage: [1, 1, 0, 1])
        let b = Matrix<Double>(rows: 2, columns: 2, storage: [1, 0, 1, 1])
        let c = Matrix<Double>(rows: 2, columns: 2, storage: [2, 0, 0, 2])
        let A = Matrix<Double>.Product(a)
        let B = Matrix<Double>.Product(b)
        let C = Matrix<Double>.Product(c)
        XCTAssertEqual(
            Matrix<Double>.Product.combine(Matrix<Double>.Product.combine(A, B), C).rawValue,
            Matrix<Double>.Product.combine(A, Matrix<Double>.Product.combine(B, C)).rawValue
        )
    }

    func testProductSconcatFoldsThroughCombine() {
        // [[1,1],[0,1]]^4 should be [[1,4],[0,1]]
        let A = Matrix<Double>(rows: 2, columns: 2, storage: [1, 1, 0, 1])
        let wrapped = Array(repeating: Matrix<Double>.Product(A), count: 4)
        let result = sconcat(wrapped[0], Array(wrapped.dropFirst()))
        XCTAssertEqual(result.rawValue, Matrix(rows: 2, columns: 2, storage: [1, 4, 0, 1]))
    }
}
