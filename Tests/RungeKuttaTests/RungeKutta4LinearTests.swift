// SPDX-License-Identifier: Apache-2.0

import DataStructure
import Math
import RungeKutta
import Testing

// The propagator is RK4 on `dy/dt = A·y`, not an approximation of it: stepping `rk4` with that
// derivative has to land on the same states, up to rounding, for any constant `A`.

/// A compartment-like matrix: non-negative transfers off the diagonal, each column's outflow (plus
/// a decay) on the diagonal, so the system is stable, as biokinetic models are.
private func compartmental(size n: Int, seed: UInt64) -> Matrix<Double> {
    var rng = SplitMix64(seed: seed)
    var entries = [Double](repeating: 0, count: n * n)
    for from in 0 ..< n {
        for to in 0 ..< n where to != from {
            entries[to * n + from] = Bool.random(using: &rng) ? Double.random(in: 0 ..< 2, using: &rng) : 0
        }
        let outflow = (0 ..< n).reduce(0.0) { $0 + entries[$1 * n + from] }
        entries[from * n + from] = -outflow - Double.random(in: 0 ..< 0.1, using: &rng)
    }
    return Matrix(rows: n, columns: n, storage: entries)
}

@Suite("RK4 propagator on linear systems")
struct RungeKutta4LinearTests {
    @Test(arguments: [(UInt64(1), 3), (2, 6), (3, 12), (4, 19)])
    func linearTrajectoryMatchesSteppingRK4(seed: UInt64, size: Int) {
        let A = compartmental(size: size, seed: seed)
        let y0 = (0 ..< size).map { $0 == 0 ? 1.0 : 0 }
        let (h, perSample, samples) = (0.01, 10, 50)

        let span = Double(perSample * samples) * h
        let stepped = RungeKutta4.trajectory(from: y0, derivative: { _, y in A.apply(to: y) }, step: h, through: span)
        let linear = RungeKutta4.linearTrajectory(of: A, from: y0, step: h, stepsPerSample: perSample, count: samples)

        #expect(linear.count == samples + 1)
        for (i, state) in linear.enumerated() {
            let reference = stepped[i * perSample].state
            let error = zip(state, reference).map { abs($0 - $1) }.max() ?? 0
            #expect(error < 1e-13, "sample \(i): \(error)")
        }
    }

    @Test func oneStepOfThePropagatorIsOneRK4Step() {
        let A = compartmental(size: 5, seed: 9)
        let y0 = [0.3, 0.1, 0.4, 0.15, 0.05]
        let h = 0.05
        let viaPropagator = RungeKutta4.propagator(of: A, step: h).apply(to: y0)
        let viaStages = y0 + RungeKutta4.rk4 { (_: Double, y: [Double]) in A.apply(to: y) }(0, y0, h)
        let error = zip(viaPropagator, viaStages).map { abs($0 - $1) }.max() ?? 0
        #expect(error < 1e-15)
    }
}
