// SPDX-License-Identifier: Apache-2.0

import Foundation
import Math
import RungeKutta
import Testing

// A stopped integration is reported, never padded with its last state. The stiff case is the one
// that used to go wrong: `y' = −50·y` holds Dormand–Prince near h ≈ 3.3 / 50, so 100 time units
// need ~1,500 steps, and a 200-step budget runs out a few units in.

private let stiff: @Sendable (Double, Double) -> Double = { _, y in -50 * y }

@Suite("RK45 reports why it stopped")
struct RungeKutta45FailureTests {
    @Test func aBudgetThatRunsOutIsAFailureNotAFlatTail() throws {
        let result = RungeKutta45.trajectory(at: [1, 50, 100], from: 1.0, derivative: stiff, tolerance: 1e-8, maxIterations: 200)
        guard case let .failure(.stepLimit(reached, steps)) = result else {
            Issue.record("expected .stepLimit, got \(result)")
            return
        }
        #expect(steps == 200)
        #expect(reached > 0 && reached < 100)
    }

    @Test func denseSegmentsFailsTheSameWay() {
        let result = RungeKutta45.denseSegments(from: 1.0, derivative: stiff, through: 100, tolerance: 1e-8, maxIterations: 200)
        guard case .failure(.stepLimit) = result else {
            Issue.record("expected .stepLimit, got \(result)")
            return
        }
    }

    @Test func aBudgetSizedToTheStabilityLimitReachesTheEnd() throws {
        // span × rate / 3.3 ≈ 1,515 steps; twice that is plenty.
        let result = RungeKutta45.trajectory(at: [1, 50, 100], from: 1.0, derivative: stiff, tolerance: 1e-10, maxIterations: 3_000)
        let values = try result.get()
        #expect(abs(values[0] - exp(-50)) < 1e-10)
        #expect(abs(values[2] - exp(-5_000)) < 1e-10)
    }

    @Test func aStepFloorTheProblemNeedsToGoBelowIsAnUnderflow() {
        let result = RungeKutta45.trajectory(at: [10], from: 1.0, derivative: stiff, tolerance: 1e-8, minStep: 0.5)
        guard case let .failure(.stepUnderflow(at, step)) = result else {
            Issue.record("expected .stepUnderflow, got \(result)")
            return
        }
        #expect(at < 10)
        #expect(step <= 0.5)
    }
}
