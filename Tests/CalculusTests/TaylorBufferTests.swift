// SPDX-License-Identifier: Apache-2.0

import Calculus
import Math
import Testing

@Suite("Taylor series in reused buffers")
struct TaylorBufferTests {
    @Test func exponentialMatchesTheOperatorFormula() {
        let a = Matrix<Double>(rows: 3, columns: 3, storage: [-0.5, 0, 0.02, 0.4, -0.7, 0, 0.01, 0.3, -0.9])
        var sum = Matrix<Double>.identity(size: 3)
        var term = Matrix<Double>.identity(size: 3)
        for r in 1 ... 10_000 {
            term = (1 / Double(r)) * (term * a)
            sum += term
            if Taylor.converged(term: term, sum: sum, tolerance: 1e-10) { break }
        }
        #expect(Taylor.exponential(of: a) == sum)
    }
}
