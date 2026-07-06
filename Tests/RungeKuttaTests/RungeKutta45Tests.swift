// SPDX-License-Identifier: Apache-2.0

import Math
@testable import RungeKutta
import XCTest

final class RungeKutta45Tests: XCTestCase {
    // MARK: - Scalar exponential decay (analytic reference)

    /// `y' = −k·y`, exact `y(t) = y₀·e^{−k·t}`. The "linear" RK45 sweet spot:
    /// the integrator should adapt the step to keep error near tolerance.
    func testScalarExponentialDecayMatchesAnalyticAtRequestedTimes() {
        let k = 0.3
        let y0 = 5.0
        let exact: (Double) -> Double = { t in y0 * exp(-k * t) }

        let outputTimes = [0.0, 1.0, 2.5, 5.0, 10.0, 15.0, 20.0]
        let values = RungeKutta45.trajectory(
            at: outputTimes,
            from: y0,
            derivative: { _, y in -k * y },
            tolerance: 1e-8
        )

        XCTAssertEqual(values.count, outputTimes.count)
        XCTAssertEqual(values.first, y0)
        for (t, value) in zip(outputTimes, values) {
            XCTAssertEqual(value, exact(t), accuracy: 1e-6, "at t=\(t)")
        }
    }

    // MARK: - Vector harmonic oscillator (analytic reference)

    /// `d²x/dt² = -ω²·x`, written as the coupled first-order system
    /// `y = [x, x'], dy/dt = [x', −ω²·x]`. Exact closed form
    /// `x(t) = cos(ω·t), x'(t) = −ω·sin(ω·t)`. With dense output, every
    /// requested time gets cubic-Hermite interpolated values.
    func testHarmonicOscillatorMatchesAnalyticAtRequestedTimes() {
        let omega = 2.0
        let exact: (Double) -> [Double] = { t in
            [cos(omega * t), -omega * sin(omega * t)]
        }

        let derivative: @Sendable (Double, [Double]) -> [Double] = { _, y in
            [y[1], -omega * omega * y[0]]
        }

        let outputTimes = Array(stride(from: 0.0, through: 10.0, by: 1.0))
        let values = RungeKutta45.trajectory(
            at: outputTimes,
            from: [1.0, 0.0],
            derivative: derivative,
            tolerance: 1e-10
        )

        for (t, value) in zip(outputTimes, values) {
            let expected = exact(t)
            for i in 0 ..< 2 {
                XCTAssertEqual(value[i], expected[i], accuracy: 1e-5, "at t=\(t), component \(i)")
            }
        }
    }

    // MARK: - Linear coupled system (matches Birchall-style biokinetic shape)

    /// Two-compartment cascade: `A → B → ∅` with rate constant `k = 0.1/day`.
    /// `dA/dt = −k·A, dB/dt = k·A − k·B`. Initial `[A, B] = [1, 0]`.
    /// Exact: `A(t) = e^{−k·t}`, `B(t) = k·t·e^{−k·t}`. This is the linear ODE
    /// shape biokinetic compartmental models live in.
    func testTwoCompartmentCascadeMatchesAnalyticAtRequestedTimes() {
        let k = 0.1
        let exact: (Double) -> [Double] = { t in
            let decay = exp(-k * t)
            return [decay, k * t * decay]
        }

        let derivative: @Sendable (Double, [Double]) -> [Double] = { _, y in
            [-k * y[0], k * y[0] - k * y[1]]
        }

        let outputTimes = [0.0, 1.0, 5.0, 10.0, 25.0, 50.0]
        let values = RungeKutta45.trajectory(
            at: outputTimes,
            from: [1.0, 0.0],
            derivative: derivative,
            tolerance: 1e-10
        )

        for (t, value) in zip(outputTimes, values) {
            let expected = exact(t)
            XCTAssertEqual(value[0], expected[0], accuracy: 1e-7, "A at t=\(t)")
            XCTAssertEqual(value[1], expected[1], accuracy: 1e-7, "B at t=\(t)")
        }
    }

    // MARK: - Adaptivity sanity check (segments-based)

    /// On a smooth problem, the adaptive integrator should accept noticeably
    /// fewer steps than the equivalent fixed-step RK4 would need.
    /// `denseSegments` exposes the integrator's own time grid for this kind of
    /// diagnostic without going through the dense-output interpolation.
    func testAdaptiveSegmentCountStaysFarBelowFixedStep() {
        let k = 0.3
        let segments = RungeKutta45.denseSegments(
            from: 5.0,
            derivative: { _, y in -k * y },
            through: 20,
            tolerance: 1e-6
        )

        // RK4 fixed step of 0.05 would emit 400 steps over [0, 20]. RK45 on a
        // smooth exponential with tol=1e-6 should comfortably accept far fewer.
        XCTAssertLessThan(segments.count, 100, "expected adaptive to be << fixed-step")
        XCTAssertGreaterThan(segments.count, 1, "expected at least a couple of accepted steps")
    }

    // MARK: - Exact landing on a requested output time

    func testRequestedTimeReturnsValueAtThatTimeExactly() {
        let end = 13.7
        let values = RungeKutta45.trajectory(
            at: [end],
            from: 1.0,
            derivative: { _, y in -0.5 * y },
            tolerance: 1e-8
        )
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0], exp(-0.5 * end), accuracy: 1e-6)
    }

    // MARK: - Edge cases

    func testEmptyOutputTimesReturnsEmptyArray() {
        let values: [Double] = RungeKutta45.trajectory(
            at: [],
            from: 1.0,
            derivative: { _, y in y },
            tolerance: 1e-6
        )
        XCTAssertTrue(values.isEmpty)
    }

    func testOutputTimeAtStartReturnsInitialState() {
        let values = RungeKutta45.trajectory(
            at: [5.0],
            from: 42.0,
            derivative: { _, y in y },
            startingAt: 5.0,
            tolerance: 1e-6
        )
        XCTAssertEqual(values, [42.0])
    }

    func testOutputTimeBeforeStartReturnsInitialState() {
        let values = RungeKutta45.trajectory(
            at: [-1.0, 0.0, 1.0],
            from: 3.0,
            derivative: { _, y in -y },
            startingAt: 0.0,
            tolerance: 1e-8
        )
        XCTAssertEqual(values[0], 3.0)
        XCTAssertEqual(values[1], 3.0)
        XCTAssertEqual(values[2], 3.0 * exp(-1.0), accuracy: 1e-6)
    }

    // MARK: - Tighter tolerance ⇒ more accepted segments

    func testTighterToleranceProducesMoreSegments() {
        let derivative: @Sendable (Double, Double) -> Double = { _, y in -0.3 * y }
        let loose = RungeKutta45.denseSegments(
            from: 5.0,
            derivative: derivative,
            through: 20,
            tolerance: 1e-3
        )
        let tight = RungeKutta45.denseSegments(
            from: 5.0,
            derivative: derivative,
            through: 20,
            tolerance: 1e-10
        )
        XCTAssertGreaterThan(tight.count, loose.count)
    }
}
