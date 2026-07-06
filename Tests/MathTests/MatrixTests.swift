// SPDX-License-Identifier: Apache-2.0

@testable import Math
import MathOperators
import XCTest

final class MatrixTests: XCTestCase {
    private let tolerance = 1e-12

    private let A = Matrix<Double>(rows: 2, columns: 2, storage: [1, 2, 3, 4])
    private let B = Matrix<Double>(rows: 2, columns: 2, storage: [5, 6, 7, 8])
    private let C = Matrix<Double>(rows: 2, columns: 2, storage: [9, 8, 7, 6])

    func testSubscriptRowMajor() {
        XCTAssertEqual(A[0, 0], 1)
        XCTAssertEqual(A[0, 1], 2)
        XCTAssertEqual(A[1, 0], 3)
        XCTAssertEqual(A[1, 1], 4)
    }

    func testIdentityIsDiagonalOnes() {
        XCTAssertEqual(Matrix<Double>.identity(size: 3).storage, [1, 0, 0, 0, 1, 0, 0, 0, 1])
    }

    func testZeroIsAllZeros() {
        XCTAssertEqual(Matrix<Double>.zero(size: 3).storage, Array(repeating: 0, count: 9))
    }

    func testAddIsCommutative() {
        assertEqual(A + B, B + A)
    }

    func testAddIsAssociative() {
        assertEqual((A + B) + C, A + (B + C))
    }

    func testAddZeroIsIdentity() {
        assertEqual(A + Matrix<Double>.zero(size: 2), A)
    }

    func testScalarMultiplyDistributesOverAddition() {
        assertEqual(3 * (A + B), 3 * A + 3 * B)
    }

    func testScalarMultiplyByOneIsIdentity() {
        assertEqual(1.0 * A, A)
    }

    func testScalarMultiplyByZeroIsZero() {
        assertEqual(0.0 * A, Matrix<Double>.zero(size: 2))
    }

    func testMatrixMultiplyByIdentityIsIdentity() {
        let I = Matrix<Double>.identity(size: 2)
        assertEqual(A * I, A)
        assertEqual(I * A, A)
    }

    func testMatrixMultiplyByZeroIsZero() {
        let Z = Matrix<Double>.zero(size: 2)
        assertEqual(A * Z, Z)
        assertEqual(Z * A, Z)
    }

    func testMatrixMultiplyIsAssociative() {
        assertEqual((A * B) * C, A * (B * C))
    }

    func testMatrixMultiplyDistributesOverAddition() {
        assertEqual(A * (B + C), A * B + A * C)
        assertEqual((A + B) * C, A * C + B * C)
    }

    func testMatrixMultiplyConcreteCase() {
        let product = A * B
        XCTAssertEqual(product[0, 0], 1 * 5 + 2 * 7)
        XCTAssertEqual(product[0, 1], 1 * 6 + 2 * 8)
        XCTAssertEqual(product[1, 0], 3 * 5 + 4 * 7)
        XCTAssertEqual(product[1, 1], 3 * 6 + 4 * 8)
    }

    func testApplyToVectorMatchesMultiplyByColumnMatrix() {
        let v: [Double] = [10, 20]
        let result = A.apply(to: v)
        XCTAssertEqual(result[0], 1 * 10 + 2 * 20, accuracy: tolerance)
        XCTAssertEqual(result[1], 3 * 10 + 4 * 20, accuracy: tolerance)
    }

    func testApplyIdentityIsVector() {
        let v: [Double] = [1, 2, 3]
        XCTAssertEqual(Matrix<Double>.identity(size: 3).apply(to: v), v)
    }

    func testNonSquareMatrixMultiply() {
        let M = Matrix<Double>(rows: 2, columns: 3, storage: [1, 2, 3, 4, 5, 6])
        let N = Matrix<Double>(rows: 3, columns: 2, storage: [7, 8, 9, 10, 11, 12])
        let product = M * N
        XCTAssertEqual(product.rows, 2)
        XCTAssertEqual(product.columns, 2)
        XCTAssertEqual(product[0, 0], 58.0) // 1·7 + 2·9 + 3·11
        XCTAssertEqual(product[1, 1], 154.0) // 4·8 + 5·10 + 6·12
    }

    func testWithReplacesCellWithoutMutatingOriginal() {
        let updated = A.with(row: 0, column: 1, value: 99)
        XCTAssertEqual(updated[0, 1], 99)
        XCTAssertEqual(A[0, 1], 2, "original is unchanged")
    }

    func testSquaredZeroTimesIsIdentityFunction() {
        XCTAssertEqual(A.squared(times: 0), A)
    }

    func testSquaredOnceMatchesSelfMultiply() {
        assertEqual(A.squared(times: 1), A * A)
    }

    func testSquaredTwiceIsFourthPower() {
        let A2 = A * A
        assertEqual(A.squared(times: 2), A2 * A2)
    }

    func testDotOperatorMatrixMatrix() {
        assertEqual(A ⋅ B, A * B)
    }

    func testDotOperatorScalarMatrix() {
        assertEqual(3.0 ⋅ A, 3.0 * A)
    }

    func testDotOperatorMatrixVector() {
        let v: [Double] = [10, 20]
        XCTAssertEqual(A ⋅ v, A.apply(to: v))
    }

    // MARK: - In-place arithmetic

    func testPlusEqualMatchesPlus() {
        var lhs = A
        lhs += B
        assertEqual(lhs, A + B)
    }

    func testSubtractionAndMinusEqual() {
        let diff = A - B
        var lhs = A
        lhs -= B
        assertEqual(diff + B, A)
        assertEqual(lhs, diff)
    }

    func testScalarStarEqualMatchesScalarMultiply() {
        var lhs = A
        lhs *= 3.0
        assertEqual(lhs, 3.0 * A)
    }

    func testMatrixStarEqualMatchesMatrixMultiply() {
        var lhs = A
        lhs *= B
        assertEqual(lhs, A * B)
    }

    private func assertEqual(_ lhs: Matrix<Double>, _ rhs: Matrix<Double>, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.rows, rhs.rows, file: file, line: line)
        XCTAssertEqual(lhs.columns, rhs.columns, file: file, line: line)
        for (l, r) in zip(lhs.storage, rhs.storage) {
            XCTAssertEqual(l, r, accuracy: tolerance, file: file, line: line)
        }
    }
}
