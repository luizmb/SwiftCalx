// SPDX-License-Identifier: Apache-2.0

import Math
@testable import RungeKutta
import XCTest

final class RungeKutta45HermiteTests: XCTestCase {
    // MARK: - Cubic Hermite endpoint conditions

    func testCubicHermiteAtStartReturnsStartState() {
        let segment = RungeKutta45.Segment<Double>(
            startTime: 1.0,
            endTime: 3.0,
            startState: 7.0,
            endState: 11.0,
            startSlope: 2.0,
            endSlope: -1.0
        )
        XCTAssertEqual(RungeKutta45.cubicHermite(at: 1.0, on: segment), 7.0, accuracy: 1e-12)
    }

    func testCubicHermiteAtEndReturnsEndState() {
        let segment = RungeKutta45.Segment<Double>(
            startTime: 1.0,
            endTime: 3.0,
            startState: 7.0,
            endState: 11.0,
            startSlope: 2.0,
            endSlope: -1.0
        )
        XCTAssertEqual(RungeKutta45.cubicHermite(at: 3.0, on: segment), 11.0, accuracy: 1e-12)
    }

    /// For a linear function `y(t) = a + b·t` the cubic Hermite reproduces the
    /// straight line exactly: y(t₀), y(t₁), m₀ = m₁ = b. Cubic Hermite agrees
    /// at the midpoint.
    func testCubicHermiteOnLinearFunctionIsExact() {
        // y = 2 + 3t — slope is 3 everywhere
        let segment = RungeKutta45.Segment<Double>(
            startTime: 0.0,
            endTime: 4.0,
            startState: 2.0,
            endState: 14.0,
            startSlope: 3.0,
            endSlope: 3.0
        )
        for t in stride(from: 0.0, through: 4.0, by: 0.5) {
            XCTAssertEqual(
                RungeKutta45.cubicHermite(at: t, on: segment),
                2.0 + 3.0 * t,
                accuracy: 1e-12,
                "at t=\(t)"
            )
        }
    }

    /// For a cubic polynomial passing through both endpoints with the right slopes,
    /// cubic Hermite reproduces it exactly. Take `y(t) = t³`: at t=1, y=1, slope=3;
    /// at t=2, y=8, slope=12.
    func testCubicHermiteOnCubicPolynomialIsExact() {
        let segment = RungeKutta45.Segment<Double>(
            startTime: 1.0,
            endTime: 2.0,
            startState: 1.0,
            endState: 8.0,
            startSlope: 3.0,
            endSlope: 12.0
        )
        for t in stride(from: 1.0, through: 2.0, by: 0.1) {
            XCTAssertEqual(
                RungeKutta45.cubicHermite(at: t, on: segment),
                t * t * t,
                accuracy: 1e-12,
                "at t=\(t)"
            )
        }
    }

    /// Vector states should interpolate elementwise; pair two independent
    /// linear components in `[Double]` and confirm both reproduce.
    func testCubicHermiteOnVectorStateInterpolatesElementwise() {
        // Component 0: linear, slope 1. Component 1: linear, slope -2.
        let segment = RungeKutta45.Segment<[Double]>(
            startTime: 0.0,
            endTime: 2.0,
            startState: [0.0, 5.0],
            endState: [2.0, 1.0],
            startSlope: [1.0, -2.0],
            endSlope: [1.0, -2.0]
        )
        let mid = RungeKutta45.cubicHermite(at: 1.0, on: segment)
        XCTAssertEqual(mid[0], 1.0, accuracy: 1e-12)
        XCTAssertEqual(mid[1], 3.0, accuracy: 1e-12)
    }

    // MARK: - Continuity at segment boundary

    /// Cubic Hermite is C¹-continuous across adjacent segments that share an
    /// endpoint state and slope. Interpolating just-below and just-above a
    /// segment join should produce values that bracket the join's value.
    func testCubicHermiteIsContinuousAtSegmentJoin() {
        let dydt: @Sendable (Double, Double) -> Double = { _, y in -0.5 * y }
        let segments = RungeKutta45.denseSegments(
            from: 1.0,
            derivative: dydt,
            startingAt: 0,
            through: 10,
            tolerance: 1e-9
        )
        // Pick a segment boundary in the middle of the trajectory.
        guard segments.count >= 3 else {
            XCTFail("expected at least 3 accepted segments to test continuity")
            return
        }
        let join = segments[segments.count / 2].startTime
        let before = RungeKutta45.trajectory(
            at: [join - 1e-9],
            from: 1.0,
            derivative: dydt,
            tolerance: 1e-9
        )[0]
        let after = RungeKutta45.trajectory(
            at: [join + 1e-9],
            from: 1.0,
            derivative: dydt,
            tolerance: 1e-9
        )[0]
        XCTAssertEqual(before, after, accuracy: 1e-7)
    }
}
