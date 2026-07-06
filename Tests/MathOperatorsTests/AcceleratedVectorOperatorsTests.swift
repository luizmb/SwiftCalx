// SPDX-License-Identifier: Apache-2.0

import Math
import MathOperators
import XCTest

final class VectorOperatorsTests: XCTestCase {
    private let tolerance = 1e-13

    func testMatrixDotVector() {
        let A = Matrix<Double>(rows: 2, columns: 3, storage: [
            1, 2, 3,
            4, 5, 6
        ])
        let v = AcceleratedVector([1.0, 2.0, 3.0])
        XCTAssertEqual(A ⋅ v, AcceleratedVector([14.0, 32.0]))
    }

    func testScalarDotVector() {
        XCTAssertEqual(3.0 ⋅ AcceleratedVector([1.0, 2.0, 3.0]),
                       AcceleratedVector([3.0, 6.0, 9.0]))
    }

    func testVectorDotProduct() {
        let u = AcceleratedVector([1.0, 2.0, 3.0])
        let v = AcceleratedVector([4.0, 5.0, 6.0])
        XCTAssertEqual(u ⋅ v, 32.0, accuracy: tolerance) // 1·4 + 2·5 + 3·6
    }

    func testDotProductWithOrthogonalVectorsIsZero() {
        let u = AcceleratedVector([1.0, 0.0])
        let v = AcceleratedVector([0.0, 1.0])
        XCTAssertEqual(u ⋅ v, 0.0, accuracy: tolerance)
    }

    func testDotProductWithSelfIsSquaredNorm() {
        let v = AcceleratedVector([3.0, 4.0])
        // Pythagoras: ||v||² = 9 + 16 = 25
        XCTAssertEqual(v ⋅ v, 25.0, accuracy: tolerance)
    }
}
