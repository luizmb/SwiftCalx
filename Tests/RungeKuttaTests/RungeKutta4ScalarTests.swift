// SPDX-License-Identifier: Apache-2.0

import Math
@testable import RungeKutta
import XCTest

final class RungeKutta4ScalarTests: XCTestCase {
    /// Rosettacode regression: `y' = x·√y`, `y(0) = 1`, exact `y(x) = (x² + 4)² / 16`.
    /// Catches the historical "double-add of pt𝓃.y" bug in `rk4`.
    func testRosettacode() {
        let exact: (Double) -> Double = { x in pow(x * x + 4, 2) / 16 }
        let derivative: (BidimensionalPoint<Double>) -> Double = { p in p.x * sqrt(p.y) }
        let step = 0.1
        let trajectory = integrate(
            derivative: derivative,
            from: BidimensionalPoint(x: 0, y: 1),
            to: 10,
            step: step
        )
        for sampleX in 0 ... 10 {
            let actual = trajectory[sampleX * 10].y
            XCTAssertEqual(actual, exact(Double(sampleX)), accuracy: 1e-4, "at x=\(sampleX)")
        }
    }

    /// `y' = -k·y`, exact `y(x) = y₀·e^{-kx}`.
    func testExponentialDecay() {
        let k = 0.3
        let y0 = 5.0
        let exact: (Double) -> Double = { x in y0 * exp(-k * x) }
        let derivative: (BidimensionalPoint<Double>) -> Double = { p in -k * p.y }
        let step = 0.05
        let trajectory = integrate(
            derivative: derivative,
            from: BidimensionalPoint(x: 0, y: y0),
            to: 20,
            step: step
        )
        for sampleX in stride(from: 0, through: 20, by: 2) {
            let actual = trajectory[sampleX * 20].y
            XCTAssertEqual(actual, exact(Double(sampleX)), accuracy: 1e-9, "at x=\(sampleX)")
        }
    }

    /// `y' = cos(x)`, exact `y(x) = sin(x)`.
    func testSineFromCosine() {
        let derivative: (BidimensionalPoint<Double>) -> Double = { p in cos(p.x) }
        let step = 0.01
        let trajectory = integrate(
            derivative: derivative,
            from: BidimensionalPoint(x: 0, y: 0),
            to: 2 * .pi,
            step: step
        )
        for sampleX in stride(from: 0, through: 6, by: 1) {
            let actual = trajectory[sampleX * 100].y
            XCTAssertEqual(actual, sin(Double(sampleX)), accuracy: 1e-9, "at x=\(sampleX)")
        }
    }

    /// Guards the contract that `rk4` returns *pure* Δy (caller adds y₀).
    /// With `fn(p) = 0` the slope is zero, so Δy must be zero regardless of `pt𝓃.y`.
    func testRk4ReturnsPureDeltaY() {
        let zeroDerivative: (BidimensionalPoint<Double>) -> Double = { _ in 0 }
        let step = RungeKutta4.rk4(zeroDerivative)
        XCTAssertEqual(step(BidimensionalPoint(x: 0, y: 42), 1.0), 0)
        XCTAssertEqual(step(BidimensionalPoint(x: 5, y: -100), 0.5), 0)
    }

    /// A constant slope `fn(p) = c` integrates exactly: Δy over one step of size Δx is `c · Δx`.
    func testRk4ConstantSlope() {
        let step = RungeKutta4.rk4 { (_: BidimensionalPoint<Double>) in 3.0 }
        XCTAssertEqual(step(BidimensionalPoint(x: 0, y: 100), 2.0), 6.0, accuracy: 1e-12)
    }

    private func integrate(
        derivative: @escaping (BidimensionalPoint<Double>) -> Double,
        from start: BidimensionalPoint<Double>,
        to end: Double,
        step: Double
    ) -> [BidimensionalPoint<Double>] {
        stride(from: start.x + step, through: end, by: step).reduce(
            [start],
            RungeKutta4.calculateNextPoint(Δx: step, stepCalculator: RungeKutta4.rk4(derivative))
        )
    }
}
