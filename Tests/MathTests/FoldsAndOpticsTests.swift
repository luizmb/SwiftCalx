// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import Math
import Testing

private func address(_ array: [Double]) -> UnsafeRawPointer? {
    array.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) }
}

/// A copy with its own buffer and room to grow, so in-place writes and appends keep it.
private func roomy(_ array: [Double]) -> [Double] {
    var copy: [Double] = []
    copy.reserveCapacity(array.count * 4)
    copy.append(contentsOf: array)
    return copy
}

private let u = AcceleratedVector([1, 2, 3])
private let v = AcceleratedVector([10, 20])

@Suite("AcceleratedVector folds and products")
struct AcceleratedVectorFoldTests {
    @Test func reduceIntoMatchesReduce() {
        #expect(u.reduce(into: 0.0) { $0 += $1 } == u.reduce(0.0, +))
        #expect(u.reduce(into: [Double]()) { $0.append($1 * 2) } == [2, 4, 6])
    }

    @Test func productsMatchTheFlatMapDefinitions() {
        #expect(AcceleratedVector.liftA2(+)(u, v).storage == u.storage.flatMap { a in v.storage.map { a + $0 } })
        let functions: [@Sendable (Double) -> Double] = [{ $0 + 1 }, { $0 * 3 }]
        #expect(AcceleratedVector.apply(functions, v).storage == [11, 21, 30, 60])
        #expect(u.seqRight(v).storage == [10, 20, 10, 20, 10, 20])
        #expect(u.seqLeft(v).storage == [1, 1, 2, 2, 3, 3])
        #expect(AcceleratedVector.cartesian(u, v).map { [$0.0, $0.1] } == [[1, 10], [1, 20], [2, 10], [2, 20], [3, 10], [3, 20]])
        let triples = AcceleratedVector.cartesian(v, v, v).map { [$0.0, $0.1, $0.2] }
        #expect(triples.count == 8)
        #expect(triples.first == [10, 10, 10])
        #expect(triples.last == [20, 20, 20])
    }

    @Test func concatAndJoinPutVectorsEndToEnd() {
        #expect(AcceleratedVector.concat([u, v, AcceleratedVector([])]).storage == [1, 2, 3, 10, 20])
        #expect(AcceleratedVector.join([v, u]).storage == [10, 20, 1, 2, 3])
    }

    @Test func combineExtendsAHandedOverLeftSideInPlace() {
        let left = AcceleratedVector(roomy([1, 2]))
        let before = address(left.storage)
        let joined = AcceleratedVector.combine(consume left, v)
        #expect(address(joined.storage) == before)
        #expect(joined.storage == [1, 2, 10, 20])
    }

    @Test func combineLeavesASharedLeftSide() {
        let left = AcceleratedVector(roomy([1, 2]))
        let joined = AcceleratedVector.combine(left, v)
        #expect(left.storage == [1, 2])
        #expect(joined.storage == [1, 2, 10, 20])
    }
}

@Suite("AcceleratedVector optics")
struct AcceleratedVectorOpticsTests {
    @Test func eachReadsAndWritesInPlace() {
        var vector = AcceleratedVector(roomy([1, 2, 3]))
        let before = address(vector.storage)
        #expect(AcceleratedVector.each.getAll(vector) == [1, 2, 3])
        AcceleratedVector.each.modifyMut(&vector) { $0 *= 10 }
        #expect(address(vector.storage) == before)
        #expect(vector.storage == [10, 20, 30])
    }

    @Test func ixReadsAndWritesOneComponentInPlace() {
        var vector = AcceleratedVector(roomy([1, 2, 3]))
        let before = address(vector.storage)
        #expect(AcceleratedVector.ix(1).preview(vector) == 2)
        #expect(AcceleratedVector.ix(3).preview(vector) == nil)
        AcceleratedVector.ix(1).tryModifyMut(&vector) { $0 = -2 }
        #expect(address(vector.storage) == before)
        #expect(vector.storage == [1, -2, 3])
    }
}

@Suite("Matrix rows, columns and in-place edits")
struct MatrixRowColumnTests {
    private let matrix = Matrix<Double>(rows: 2, columns: 3, storage: [1, 2, 3, 4, 5, 6])

    @Test func rowAndColumnRead() {
        #expect(Matrix<Double>.row(1).getAll(matrix) == [4, 5, 6])
        #expect(Matrix<Double>.column(2).getAll(matrix) == [3, 6])
        #expect(Matrix<Double>.row(2).getAll(matrix).isEmpty)
        #expect(Matrix<Double>.column(-1).getAll(matrix).isEmpty)
    }

    @Test func rowAndColumnWriteInPlace() {
        var edited = Matrix(rows: 2, columns: 3, storage: roomy(matrix.storage))
        let before = address(edited.storage)
        Matrix<Double>.row(0).modifyMut(&edited) { $0 = 0 }
        Matrix<Double>.column(1).modifyMut(&edited) { $0 += 100 }
        #expect(address(edited.storage) == before)
        #expect(edited.storage == [0, 100, 0, 4, 105, 6])
    }

    @Test func identityHasOnesOnTheDiagonal() {
        let n = 5
        #expect(Matrix<Double>.identity(size: n).storage == (0 ..< n * n).map { $0 / n == $0 % n ? 1 : 0 })
        #expect(Matrix<Double>.identity(size: 0).storage.isEmpty)
    }

    @Test func withOnAHandedOverMatrixWritesInPlace() {
        let original = Matrix(rows: 2, columns: 3, storage: roomy(matrix.storage))
        let before = address(original.storage)
        let changed = (consume original).with(row: 1, column: 0, value: 40)
        #expect(address(changed.storage) == before)
        #expect(changed.storage == [1, 2, 3, 40, 5, 6])
    }

    @Test func withOnASharedMatrixLeavesTheOriginal() {
        let changed = matrix.with(row: 0, column: 0, value: 9)
        #expect(matrix.storage == [1, 2, 3, 4, 5, 6])
        #expect(changed.storage == [9, 2, 3, 4, 5, 6])
    }

    @Test func compoundOperatorsKeepTheShorterLengthLikeTheOperators() {
        var longer = [1.0, 2, 3]
        longer.add([10, 20], scaledBy: 1)
        #expect(longer == [1.0, 2, 3] + [10, 20])
        var lhs = Matrix<Double>(rows: 1, columns: 3, storage: [1, 2, 3])
        let rhs = Matrix<Double>(rows: 1, columns: 2, storage: [10, 20])
        let sum = lhs + rhs
        lhs += rhs
        #expect(lhs == sum)
    }
}

@Suite("Mismatched lengths stay in bounds")
struct MismatchedLengthTests {
    @Test func acceleratedVectorOperatorsUseTheShorterLength() {
        let long = AcceleratedVector([1, 2, 3])
        let short = AcceleratedVector([10, 20])
        #expect((long + short).storage == [11, 22])
        #expect((long - short).storage == [-9, -18])
    }

    @Test func doubleMatrixOperatorsUseTheShorterLength() {
        let long = Matrix<Double>(rows: 1, columns: 3, storage: [1, 2, 3])
        let short = Matrix<Double>(rows: 1, columns: 2, storage: [10, 20])
        #expect((long + short).storage == [11, 22])
        #expect((long - short).storage == [-9, -18])
    }
}
