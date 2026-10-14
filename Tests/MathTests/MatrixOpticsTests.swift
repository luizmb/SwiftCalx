// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import Math
import Testing

private func address(_ matrix: Matrix<Double>) -> UnsafeRawPointer? {
    matrix.storage.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) }
}

/// A matrix with its own buffer, so the first in-place write doesn't have to copy.
private func fresh() -> Matrix<Double> {
    Matrix(rows: 3, columns: 3, storage: (1 ... 9).map(Double.init))
}

@Suite("Matrix optics")
struct MatrixOpticsTests {
    @Test func eachVisitsEntriesRowByRow() {
        #expect(Matrix<Double>.each.getAll(fresh()) == (1 ... 9).map(Double.init))
    }

    @Test func eachWritesInPlace() {
        var matrix = fresh()
        let before = address(matrix)
        Matrix<Double>.each.modifyMut(&matrix) { $0 *= 2 }
        #expect(address(matrix) == before)
        #expect(matrix == 2 * fresh())
    }

    @Test func diagonalReadsWithoutCollecting() {
        let smallest = Matrix<Double>.diagonal.reduce(fresh(), into: Double.infinity) { $0 = min($0, $1) }
        #expect(smallest == 1)
        #expect(Matrix<Double>.diagonal.getAll(fresh()) == [1, 5, 9])
    }

    @Test func diagonalOfARectangularMatrixStopsAtTheShorterSide() {
        let wide = Matrix<Double>(rows: 2, columns: 3, storage: [1, 2, 3, 4, 5, 6])
        #expect(Matrix<Double>.diagonal.getAll(wide) == [1, 5])
    }

    @Test func diagonalWritesInPlace() {
        var matrix = fresh()
        let before = address(matrix)
        Matrix<Double>.diagonal.modifyMut(&matrix) { $0 = 0 }
        #expect(address(matrix) == before)
        #expect(matrix.storage == [0, 2, 3, 4, 0, 6, 7, 8, 0])
    }

    @Test func entryReadsAndWritesInPlace() {
        var matrix = fresh()
        let before = address(matrix)
        let entry = Matrix<Double>.entry(row: 1, column: 2)
        #expect(entry.preview(matrix) == 6)
        entry.tryModifyMut(&matrix) { $0 = 60 }
        #expect(address(matrix) == before)
        #expect(matrix == fresh().with(row: 1, column: 2, value: 60))
    }

    @Test func entryOutsideTheMatrixIsEmpty() {
        let matrix = fresh()
        // Row 0, column 5 is offset 5, inside the buffer: it must still miss.
        #expect(Matrix<Double>.entry(row: 0, column: 5).preview(matrix) == nil)
        #expect(Matrix<Double>.entry(row: 3, column: 0).preview(matrix) == nil)
        #expect(Matrix<Double>.entry(row: 0, column: 5).set(matrix, 1) == matrix)
    }

    @Test func writingASharedMatrixLeavesTheOriginal() {
        let original = fresh()
        var copy = original
        Matrix<Double>.each.modifyMut(&copy) { $0 = 0 }
        #expect(original == fresh())
        #expect(copy == Matrix<Double>.zero(size: 3))
    }
}

@Suite("Matrix products into a buffer")
struct MatrixProductBufferTests {
    @Test func multiplyIntoMatchesTheOperatorAndReusesTheBuffer() {
        let a = fresh()
        var result = fresh()
        let before = address(result)
        Matrix.multiply(a, a, into: &result)
        #expect(address(result) == before)
        #expect(result == a * a)
    }

    @Test func multiplyIntoTakesTheProductShape() {
        let a = Matrix<Double>(rows: 2, columns: 3, storage: [1, 2, 3, 4, 5, 6])
        let b = Matrix<Double>(rows: 3, columns: 1, storage: [1, 0, -1])
        var result = fresh()
        Matrix.multiply(a, b, into: &result)
        #expect(result == Matrix(rows: 2, columns: 1, storage: [-2, -2]))
    }

    @Test func squaredIsRepeatedProduct() {
        let a = 0.1 * fresh()
        let expected = (0 ..< 4).reduce(a) { acc, _ in acc * acc }
        #expect(a.squared(times: 4) == expected)
        #expect(a.squared(times: 0) == a)
    }
}
