// SPDX-License-Identifier: Apache-2.0

import Foundation
import Math
import RungeKutta
import Testing

// A stopped integration is reported, never padded with its last state, and carries what it did
// compute. The stiff case is the one that used to go wrong: `y' = −50·y` holds Dormand–Prince near
// h ≈ 3.3 / 50, so 100 time units need ~1,500 steps, and a 200-step budget runs out a few units in.

private let stiff: @Sendable (Double, Double) -> Double = { _, y in -50 * y }
private let slow: @Sendable (Double, Double) -> Double = { _, y in -0.5 * y }

@Suite("RK45 reports why it stopped, with what it computed")
struct RungeKutta45FailureTests {
    @Test func aBudgetThatRunsOutIsAFailureNotAFlatTail() throws {
        let result = RungeKutta45.trajectory(at: [1, 50, 100], from: 1.0, derivative: stiff, tolerance: 1e-8, maxIterations: 200)
        guard case let .failure(.stepLimit(reached, steps, partial)) = result else {
            Issue.record("expected .stepLimit, got \(result)")
            return
        }
        #expect(steps == 200)
        #expect(reached > 1 && reached < 50)
        #expect(partial.count == 1)
        #expect(abs(partial[0] - exp(-50)) < 1e-8)
    }

    /// The partial states are the finished run's, for every output time before the stop.
    @Test func thePartialMatchesAFinishedRunUpToTheStop() throws {
        let times = (1 ... 40).map(Double.init)
        let finished = try RungeKutta45.trajectory(at: times, from: 1.0, derivative: slow, tolerance: 1e-10).get()
        let stopped = RungeKutta45.trajectory(at: times, from: 1.0, derivative: slow, tolerance: 1e-10, maxIterations: 30)
        guard case let .failure(failure) = stopped else {
            Issue.record("expected a failure, got \(stopped)")
            return
        }
        #expect(!failure.partial.isEmpty)
        #expect(failure.partial.count == times.prefix { $0 <= failure.reachedTime }.count)
        #expect(failure.partial == Array(finished.prefix(failure.partial.count)))
    }

    @Test func denseSegmentsCarriesTheSegmentsItAccepted() {
        let result = RungeKutta45.denseSegments(from: 1.0, derivative: stiff, through: 100, tolerance: 1e-8, maxIterations: 200)
        guard case let .failure(.stepLimit(reached, _, segments)) = result else {
            Issue.record("expected .stepLimit, got \(result)")
            return
        }
        #expect(!segments.isEmpty)
        #expect(segments.last?.endTime == reached)
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
        guard case let .failure(.stepUnderflow(at, step, partial)) = result else {
            Issue.record("expected .stepUnderflow, got \(result)")
            return
        }
        #expect(at < 10)
        #expect(step <= 0.5)
        #expect(partial.isEmpty)
    }
}
