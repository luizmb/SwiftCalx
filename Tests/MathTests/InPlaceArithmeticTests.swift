// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Math
import RealNumber
import Testing

// The buffer-loop and in-place paths must give exactly what the textbook formulas give, and
// the compound operators must write into the existing storage when it's uniquely owned.

private func address(_ array: [Double]) -> UnsafeRawPointer? {
    array.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) }
}

/// A copy with its own buffer (`Array(array)` would share it), so the first in-place write
/// doesn't have to copy.
private func unique(_ array: [Double]) -> [Double] {
    var copy: [Double] = []
    copy.reserveCapacity(array.count)
    copy.append(contentsOf: array)
    return copy
}

/// Reaches `*` / `apply(to:)` through generic code only, as `⋅`, `Matrix.Product` and an
/// app's own generic helpers do.
private func genericProduct<S: ℝ>(_ lhs: Matrix<S>, _ rhs: Matrix<S>) -> Matrix<S> {
    lhs * rhs
}

private func genericApply<S: ℝ>(_ matrix: Matrix<S>, _ vector: [S]) -> [S] {
    matrix.apply(to: vector)
}

/// The definition `(A · B)[i, j] = Σₖ A[i, k] · B[k, j]`, summed in `k` order from zero.
private func textbookProduct<S: ℝ>(_ lhs: Matrix<S>, _ rhs: Matrix<S>) -> [S] {
    (0 ..< lhs.rows).flatMap { i in
        (0 ..< rhs.columns).map { j in
            (0 ..< lhs.columns).reduce(S.zero) { acc, k in acc + lhs[i, k] * rhs[k, j] }
        }
    }
}

private let lhs = Matrix<Double>(rows: 3, columns: 4, storage: (0 ..< 12).map { Double($0) * 0.37 - 1.1 })
private let rhs = Matrix<Double>(rows: 4, columns: 2, storage: (0 ..< 8).map { 2.3 - Double($0) * 0.61 })

@Suite("Matrix arithmetic paths")
struct MatrixArithmeticPathTests {
    @Test func genericProductMatchesConcreteProduct() {
        #expect(genericProduct(lhs, rhs) == lhs * rhs)
    }

    @Test func genericApplyMatchesConcreteApply() {
        let vector = [0.5, -1.25, 2.0, 3.5]
        #expect(genericApply(lhs, vector) == lhs.apply(to: vector))
    }

    @Test func decimalProductIsTheTextbookSum() {
        // Decimal never reaches BLAS: this is the Swift loop, exactly.
        let a = Matrix<Decimal>(rows: 2, columns: 3, storage: [1.5, -2, 0.25, 3, 4.75, -1])
        let b = Matrix<Decimal>(rows: 3, columns: 2, storage: [2, 0.5, -1, 1.25, 3, -2])
        #expect((a * b).storage == textbookProduct(a, b))
        #expect(a * b == Matrix(rows: 2, columns: 2, storage: textbookProduct(a, b)))
    }

    @Test func decimalApplyIsTheTextbookSum() {
        let a = Matrix<Decimal>(rows: 2, columns: 3, storage: [1.5, -2, 0.25, 3, 4.75, -1])
        let x: [Decimal] = [2, -0.5, 4]
        let row0: Decimal = 1.5 * 2 + -2 * -0.5 + 0.25 * 4
        let row1: Decimal = 3 * 2 + 4.75 * -0.5 + -1 * 4
        #expect(a.apply(to: x) == [row0, row1])
    }

    @Test func compoundAdditionWritesInPlace() {
        var acc = Matrix(rows: 3, columns: 4, storage: unique(lhs.storage))
        let before = address(acc.storage)
        acc += lhs
        #expect(address(acc.storage) == before)
        #expect(acc == lhs + lhs)
    }

    @Test func compoundSubtractionWritesInPlace() {
        var acc = Matrix(rows: 3, columns: 4, storage: unique(lhs.storage))
        let before = address(acc.storage)
        acc -= Matrix(rows: 3, columns: 4, storage: Array(repeating: 0.5, count: 12))
        #expect(address(acc.storage) == before)
        #expect(acc == lhs - Matrix(rows: 3, columns: 4, storage: Array(repeating: 0.5, count: 12)))
    }

    @Test func compoundScalingWritesInPlace() {
        var acc = Matrix(rows: 3, columns: 4, storage: unique(lhs.storage))
        let before = address(acc.storage)
        acc *= 1.75
        #expect(address(acc.storage) == before)
        #expect(acc == 1.75 * lhs)
    }

    @Test func compoundOperatorOnSharedStorageLeavesTheOriginal() {
        let original = Matrix(rows: 3, columns: 4, storage: unique(lhs.storage))
        var copy = original
        copy += original
        #expect(original == lhs)
        #expect(copy == lhs + lhs)
    }

    @Test func withChangesOneEntryOnly() {
        let changed = lhs.with(row: 1, column: 2, value: 42)
        #expect(changed[1, 2] == 42)
        #expect(lhs[1, 2] == 0.37 * 6 - 1.1)
        #expect(changed.storage.enumerated().allSatisfy { $0.offset == 6 || $0.element == lhs.storage[$0.offset] })
    }
}

@Suite("VectorState in place")
struct VectorStateInPlaceTests {
    private let y = (0 ..< 16).map { Double($0) * 0.13 - 0.7 }
    private let k = (0 ..< 16).map { 1.9 - Double($0) * 0.27 }

    @Test func arraySumAndScaleMatchZipAndMap() {
        #expect(y + k == zip(y, k).map(+))
        #expect(0.3 * y == y.map { 0.3 * $0 })
    }

    @Test func arraySumOfDifferentLengthsIsAsLongAsTheShorter() {
        #expect([1.0, 2, 3] + [10.0, 20] == [11, 22])
    }

    @Test func arrayAddScaledMatchesTheOperatorsAndWritesInPlace() {
        var state = unique(y)
        let before = address(state)
        state.add(k, scaledBy: 0.3)
        #expect(address(state) == before)
        #expect(state == y + 0.3 * k)
    }

    @Test func scalarAddScaledUsesTheOperators() {
        var state = 1.5
        state.add(2.25, scaledBy: -0.5)
        #expect(state == 1.5 + -0.5 * 2.25)
    }

    @Test func acceleratedVectorAddScaledMatchesTheOperatorsAndWritesInPlace() {
        var state = AcceleratedVector(unique(y))
        let before = address(state.storage)
        state.add(AcceleratedVector(k), scaledBy: 0.3)
        #expect(address(state.storage) == before)
        #expect(state == AcceleratedVector(y) + 0.3 * AcceleratedVector(k))
    }

    @Test func acceleratedVectorCompoundOperatorsWriteInPlace() {
        var state = AcceleratedVector(unique(y))
        let before = address(state.storage)
        state += AcceleratedVector(k)
        state -= AcceleratedVector(y)
        state *= 2
        #expect(address(state.storage) == before)
        #expect(state == 2 * ((AcceleratedVector(y) + AcceleratedVector(k)) - AcceleratedVector(y)))
    }

    @Test func infinityNormIsTheLargestMagnitude() {
        #expect([0.5, -3.25, 2.0].infinityNorm == 3.25)
        #expect([Double]().infinityNorm == 0)
    }
}
