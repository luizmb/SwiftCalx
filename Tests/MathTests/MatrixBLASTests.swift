// SPDX-License-Identifier: Apache-2.0

import Math
import XCTest

/// Validates that the BLAS-accelerated Matrix operations (when available)
/// produce results numerically equivalent to the scalar Swift fallback.
///
/// Single test suite runs against whichever backend is currently compiled in:
/// - macOS default build → Accelerate (`cblas_*` + `vDSP_*`)
/// - macOS with `-D SWIFTCALX_NO_ACCELERATE` → scalar Swift
/// - Linux with `libopenblas-dev` installed → OpenBLAS (`cblas_*`)
/// - Linux without OpenBLAS → scalar Swift
///
/// CI exercises all four cells. The expected results below are hand-computed
/// (or derived from symbolic identities); both backends must reach them
/// within a tight ULP-level tolerance.
final class MatrixBLASTests: XCTestCase {
    private let tolerance = 1e-13

    // MARK: - mat-vec correctness

    func testMatVecDoubleMatchesHandComputed() {
        let A = Matrix<Double>(rows: 3, columns: 4, storage: [
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12
        ])
        let x: [Double] = [1, 2, 3, 4]
        // Row 0: 1·1 + 2·2 + 3·3 + 4·4 = 30
        // Row 1: 5·1 + 6·2 + 7·3 + 8·4 = 70
        // Row 2: 9·1 + 10·2 + 11·3 + 12·4 = 110
        let result = A.apply(to: x)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], 30, accuracy: tolerance)
        XCTAssertEqual(result[1], 70, accuracy: tolerance)
        XCTAssertEqual(result[2], 110, accuracy: tolerance)
    }

    func testMatVecFloatMatchesHandComputed() {
        let A = Matrix<Float>(rows: 2, columns: 3, storage: [
            1, 2, 3,
            4, 5, 6
        ])
        let x: [Float] = [10, 20, 30]
        // Row 0: 1·10 + 2·20 + 3·30 = 140
        // Row 1: 4·10 + 5·20 + 6·30 = 320
        let result = A.apply(to: x)
        XCTAssertEqual(result[0], 140, accuracy: 1e-5)
        XCTAssertEqual(result[1], 320, accuracy: 1e-5)
    }

    func testMatVecOnIdentityIsTheVector() {
        let I = Matrix<Double>.identity(size: 5)
        let v: [Double] = [1.5, -2.5, 3.5, -4.5, 5.5]
        XCTAssertEqual(I.apply(to: v), v)
    }

    // MARK: - mat-mat correctness

    func testMatMatDoubleMatchesHandComputed() {
        let A = Matrix<Double>(rows: 2, columns: 3, storage: [
            1, 2, 3,
            4, 5, 6
        ])
        let B = Matrix<Double>(rows: 3, columns: 2, storage: [
            7, 8,
            9, 10,
            11, 12
        ])
        let C = A * B
        XCTAssertEqual(C.rows, 2)
        XCTAssertEqual(C.columns, 2)
        XCTAssertEqual(C[0, 0], 58, accuracy: tolerance) // 1·7+2·9+3·11
        XCTAssertEqual(C[0, 1], 64, accuracy: tolerance) // 1·8+2·10+3·12
        XCTAssertEqual(C[1, 0], 139, accuracy: tolerance) // 4·7+5·9+6·11
        XCTAssertEqual(C[1, 1], 154, accuracy: tolerance) // 4·8+5·10+6·12
    }

    func testMatMatFloatMatchesHandComputed() {
        let A = Matrix<Float>(rows: 2, columns: 2, storage: [1, 2, 3, 4])
        let B = Matrix<Float>(rows: 2, columns: 2, storage: [5, 6, 7, 8])
        let C = A * B
        XCTAssertEqual(C[0, 0], 19, accuracy: 1e-5) // 1·5+2·7
        XCTAssertEqual(C[1, 1], 50, accuracy: 1e-5) // 3·6+4·8
    }

    func testMatMatOnIdentityReturnsOperand() {
        let A = Matrix<Double>(rows: 3, columns: 3, storage: [1, 2, 3, 4, 5, 6, 7, 8, 9])
        let I = Matrix<Double>.identity(size: 3)
        let product = A * I
        XCTAssertEqual(product, A)
    }

    func testMatMatAssociativityHoldsForBlasPath() {
        let A = Matrix<Double>(rows: 3, columns: 3, storage: [1, 2, 3, 4, 5, 6, 7, 8, 9])
        let B = Matrix<Double>(rows: 3, columns: 3, storage: [2, 0, 1, 1, 2, 3, 0, 1, 1])
        let C = Matrix<Double>(rows: 3, columns: 3, storage: [1, 1, 0, 0, 1, 1, 1, 0, 1])
        let lhs = (A * B) * C
        let rhs = A * (B * C)
        for (l, r) in zip(lhs.storage, rhs.storage) {
            XCTAssertEqual(l, r, accuracy: tolerance)
        }
    }

    // MARK: - elementwise (Apple-only fast path; scalar elsewhere)

    func testMatrixAdditionMatchesElementwise() {
        let A = Matrix<Double>(rows: 2, columns: 3, storage: [1, 2, 3, 4, 5, 6])
        let B = Matrix<Double>(rows: 2, columns: 3, storage: [10, 20, 30, 40, 50, 60])
        let sum = A + B
        XCTAssertEqual(sum.storage, [11, 22, 33, 44, 55, 66])
    }

    func testMatrixSubtractionMatchesElementwise() {
        let A = Matrix<Double>(rows: 2, columns: 3, storage: [10, 20, 30, 40, 50, 60])
        let B = Matrix<Double>(rows: 2, columns: 3, storage: [1, 2, 3, 4, 5, 6])
        let diff = A - B
        XCTAssertEqual(diff.storage, [9, 18, 27, 36, 45, 54])
    }

    func testScalarMultiplyMatchesElementwise() {
        let A = Matrix<Double>(rows: 2, columns: 2, storage: [1, 2, 3, 4])
        let scaled = 3.0 * A
        XCTAssertEqual(scaled.storage, [3, 6, 9, 12])
    }

    // MARK: - larger sizes where BLAS speedup is dramatic

    /// A 32×32 multiplication catches any indexing or transposition bug that
    /// only surfaces beyond the small-matrix range.
    func testLargerMatrixMultiplicationStaysCorrect() {
        // M[i,j] = i * 32 + j   ⇒  M is a deterministic ramp.
        // For M · I_32 we expect M back, exactly.
        let storage = (0 ..< 32 * 32).map { Double($0) }
        let M = Matrix<Double>(rows: 32, columns: 32, storage: storage)
        let I = Matrix<Double>.identity(size: 32)
        let product = M * I
        XCTAssertEqual(product, M)
    }

    /// Non-square 16×64 · 64×16 — exercises a different cache-blocking branch
    /// of BLAS than square multiplications.
    func testNonSquareRectangularMultiplication() {
        let A = Matrix<Double>(rows: 16, columns: 64, storage: Array(repeating: 1.0, count: 16 * 64))
        let B = Matrix<Double>(rows: 64, columns: 16, storage: Array(repeating: 1.0, count: 64 * 16))
        let product = A * B
        // Every entry of product = Σ 1·1 over 64 elements = 64
        for entry in product.storage {
            XCTAssertEqual(entry, 64.0, accuracy: tolerance)
        }
    }
}
