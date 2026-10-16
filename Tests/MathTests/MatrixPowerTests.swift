// SPDX-License-Identifier: Apache-2.0

import Math
import Testing

@Suite("Matrix.raised(to:)")
struct MatrixPowerTests {
    private let m = Matrix<Double>(rows: 3, columns: 3, storage: [0.9, 0.05, 0, 0.1, 0.8, 0.02, 0, 0.15, 0.97])

    @Test func zeroAndNegativeExponentsAreTheIdentity() {
        #expect(m.raised(to: 0) == .identity(size: 3))
        #expect(m.raised(to: -2) == .identity(size: 3))
    }

    @Test(arguments: Array(1 ... 17))
    func matchesRepeatedMultiplication(exponent: Int) {
        let repeated = (1 ..< exponent).reduce(m) { acc, _ in acc * m }
        let error = zip(m.raised(to: exponent).storage, repeated.storage).map { abs($0 - $1) }.max() ?? 0
        #expect(error < 1e-15)
    }

    @Test func powersOfTwoMatchSquaring() {
        #expect(m.raised(to: 16) == m.squared(times: 4))
    }
}
