// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import RungeKutta
import XCTest

final class RungeKutta4VectorTests: XCTestCase {
    /// Bateman 2-compartment `a → b` with rate `k`.
    /// Closed form: `a(t) = e^{-kt}`, `b(t) = 1 - e^{-kt}`.
    func testBatemanTwoCompartment() {
        let k = 0.1
        let derivative: (Double, [Double]) -> [Double] = { _, y in
            [-k * y[0], k * y[0]]
        }
        let trajectory = integrate(derivative: derivative, from: [1, 0], to: 50, step: 0.1)
        for t in [0, 1, 5, 10, 25, 50] {
            let state = trajectory[t * 10].state
            XCTAssertEqual(state[0], exp(-k * Double(t)), accuracy: 1e-10, "a at t=\(t)")
            XCTAssertEqual(state[1], 1 - exp(-k * Double(t)), accuracy: 1e-10, "b at t=\(t)")
        }
    }

    /// Bateman 3-compartment `a → b → c` with rates k₁, k₂.
    func testBatemanThreeCompartment() {
        let k1 = 0.1
        let k2 = 0.05
        let derivative: (Double, [Double]) -> [Double] = { _, y in
            [-k1 * y[0], k1 * y[0] - k2 * y[1], k2 * y[1]]
        }
        let trajectory = integrate(derivative: derivative, from: [1, 0, 0], to: 100, step: 0.1)
        for t in [0, 1, 5, 10, 25, 50, 100] {
            let tD = Double(t)
            let aExpected = exp(-k1 * tD)
            let bExpected = k1 / (k2 - k1) * (exp(-k1 * tD) - exp(-k2 * tD))
            let cExpected = 1 - aExpected - bExpected
            let state = trajectory[t * 10].state
            XCTAssertEqual(state[0], aExpected, accuracy: 1e-10, "a at t=\(t)")
            XCTAssertEqual(state[1], bExpected, accuracy: 1e-10, "b at t=\(t)")
            XCTAssertEqual(state[2], cExpected, accuracy: 1e-10, "c at t=\(t)")
        }
    }

    /// Single radioactive compartment: `dy/dt = -λ·y`, exact `y(t) = e^{-λt}`.
    /// Same algorithm as scalar exponential decay, exercised through the vector API.
    func testSingleCompartmentDecay() {
        let lambda: Double = Foundation.log(2) / 10 // half-life of 10 time units
        let derivative: (Double, [Double]) -> [Double] = { _, y in [-lambda * y[0]] }
        let trajectory = integrate(derivative: derivative, from: [1], to: 50, step: 0.05)
        for t in [0, 1, 5, 10, 20, 50] {
            let state = trajectory[t * 20].state
            let expected: Double = Foundation.exp(-lambda * Double(t))
            XCTAssertEqual(state[0], expected, accuracy: 1e-10, "y at t=\(t)")
        }
    }

    /// Harmonic oscillator: `d²x/dt² = -ω²·x`. State = `[x, v]`, derivative = `[v, -ω²·x]`.
    /// Closed form: `x(t) = A·cos(ωt + φ)`. With `x(0) = 1`, `v(0) = 0` ⇒ `A = 1`, `φ = 0` ⇒ `x(t) = cos(ωt)`.
    func testHarmonicOscillator() {
        let omega = 2.0
        let derivative: (Double, [Double]) -> [Double] = { _, y in
            [y[1], -omega * omega * y[0]]
        }
        let trajectory = integrate(derivative: derivative, from: [1, 0], to: 5, step: 0.001)
        for t in [0, 1, 2, 3, 4, 5] {
            let state = trajectory[t * 1_000].state
            XCTAssertEqual(state[0], cos(omega * Double(t)), accuracy: 1e-9, "x at t=\(t)")
            XCTAssertEqual(state[1], -omega * sin(omega * Double(t)), accuracy: 1e-9, "v at t=\(t)")
        }
    }

    /// Linear system with constant coefficient matrix: `dy/dt = A·y`, exact `y(t) = exp(A·t)·y₀`.
    /// Choose `A = [[-1, 0], [0, -2]]` ⇒ diagonal ⇒ `y₁(t) = e^{-t}, y₂(t) = e^{-2t}`.
    func testDiagonalLinearSystem() {
        let derivative: (Double, [Double]) -> [Double] = { _, y in
            [-y[0], -2 * y[1]]
        }
        let trajectory = integrate(derivative: derivative, from: [1, 1], to: 5, step: 0.01)
        for t in [0, 1, 2, 3, 5] {
            let state = trajectory[t * 100].state
            XCTAssertEqual(state[0], exp(-Double(t)), accuracy: 1e-9, "y1 at t=\(t)")
            XCTAssertEqual(state[1], exp(-2 * Double(t)), accuracy: 1e-9, "y2 at t=\(t)")
        }
    }

    /// Guards that the vector `rk4` returns a *pure* Δstate (caller adds y).
    /// Zero derivative ⇒ zero Δ regardless of starting state.
    func testVectorRk4ReturnsPureDelta() {
        let zeroDerivative: (Double, [Double]) -> [Double] = { _, y in y.map { _ in 0 } }
        let step = RungeKutta4.rk4(zeroDerivative)
        XCTAssertEqual(step(0, [42, -100, 7], 1.0), [0, 0, 0])
        XCTAssertEqual(step(5, [1, 2, 3], 0.5), [0, 0, 0])
    }

    private func integrate(
        derivative: @escaping (Double, [Double]) -> [Double],
        from start: [Double],
        to end: Double,
        step: Double
    ) -> [(time: Double, state: [Double])] {
        stride(from: step, through: end, by: step).reduce(
            [(time: 0, state: start)],
            RungeKutta4.calculateNextState(Δt: step, stepCalculator: RungeKutta4.rk4(derivative))
        )
    }
}
