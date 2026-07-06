// SPDX-License-Identifier: Apache-2.0

import Foundation
import Math
import RealNumber

extension RungeKutta45 {
    /// Adaptive-step Dormand–Prince 5(4) integration of `dy/dt = f(t, y)` with
    /// **dense output**: returns the state at each user-requested time, computed
    /// by cubic-Hermite interpolation between accepted adaptive steps.
    ///
    /// ## Why dense output?
    ///
    /// Adaptive RK45 picks the steps it likes for accuracy reasons; it doesn't
    /// land on any particular grid. Naively resampling its `(time, state)` pairs
    /// by nearest neighbour or linear interpolation leaks step-size error into
    /// the output. Dense output stores the slope at each segment endpoint and
    /// uses ``cubicHermite(at:on:)`` to evaluate the trajectory at any time
    /// between accepted samples — `C¹`-continuous, locally 4th-order accurate,
    /// and decoupled from the integrator's step choices.
    ///
    /// For the algorithm itself, see ``step(from:y:k1:size:derivative:)``.
    ///
    /// - Parameters:
    ///   - outputTimes: times at which to return state. Should be sorted
    ///     ascending. The integrator runs from `startingAt` to
    ///     `max(outputTimes)`. Times before `startingAt` return `initialState`;
    ///     times after the integrated range return the last computed state.
    ///     Empty input returns `[]`.
    ///   - initialState: `y(startingAt)`.
    ///   - derivative: `f(t, y)`. Required `@Sendable`.
    ///   - startingAt: `t₀` — the initial time. Defaults to `0`.
    ///   - tolerance: target infinity-norm of `y5 − y4` per step.
    ///   - initialStep: starting `h`. Defaults to `(t_end − startingAt) / 100`.
    ///   - minStep: smallest step the integrator will try before bailing.
    ///   - maxStep: largest step the integrator will take. Defaults to the
    ///     full span — let RK45 take big strides when the dynamics allow.
    ///   - maxIterations: safety bound on total accepted + rejected steps.
    public static func trajectory<State: NormedVectorState>(
        at outputTimes: [Double],
        from initialState: State,
        derivative: @escaping @Sendable (Double, State) -> State,
        startingAt t0: Double = 0,
        tolerance: Double = 1e-6,
        initialStep: Double? = nil,
        minStep: Double? = nil,
        maxStep: Double? = nil,
        maxIterations: Int = 10_000
    ) -> [State] where State.Scalar == Double, State: Sendable {
        guard let tEnd = outputTimes.last, tEnd >= t0 else {
            return outputTimes.map { _ in initialState }
        }

        let segments = denseSegments(
            from: initialState,
            derivative: derivative,
            startingAt: t0,
            through: tEnd,
            tolerance: tolerance,
            initialStep: initialStep,
            minStep: minStep,
            maxStep: maxStep,
            maxIterations: maxIterations
        )

        return outputTimes.map { interpolate(at: $0, segments: segments, initialState: initialState) }
    }

    /// Walks the adaptive RK45 trajectory from `t0` to `t1` and returns every
    /// accepted segment with both endpoint slopes attached. Exposed publicly
    /// because some callers (e.g. diagnostic tooling) want the integrator's
    /// own time grid, not interpolated values.
    public static func denseSegments<State: NormedVectorState>(
        from initialState: State,
        derivative: @escaping @Sendable (Double, State) -> State,
        startingAt t0: Double = 0,
        through t1: Double,
        tolerance: Double = 1e-6,
        initialStep: Double? = nil,
        minStep: Double? = nil,
        maxStep: Double? = nil,
        maxIterations: Int = 10_000
    ) -> [Segment<State>] where State.Scalar == Double, State: Sendable {
        guard t1 > t0 else { return [] }

        let totalSpan = t1 - t0
        var h = initialStep ?? totalSpan / 100
        let hCap = maxStep ?? totalSpan
        let hFloor = minStep ?? 0

        var t = t0
        var y = initialState
        var k1 = derivative(t, y)
        var segments: [Segment<State>] = []
        segments.reserveCapacity(128)
        var iterations = 0

        while t < t1, iterations < maxIterations {
            iterations += 1
            let hStep = min(h, t1 - t)
            let attempt = step(from: t, y: y, k1: k1, size: hStep, derivative: derivative)

            if attempt.errorNorm <= tolerance {
                segments.append(
                    Segment(
                        startTime: t,
                        endTime: t + hStep,
                        startState: y,
                        endState: attempt.y5,
                        startSlope: k1,
                        endSlope: attempt.kLast
                    )
                )
                t += hStep
                y = attempt.y5
                k1 = attempt.kLast
                let factor = stepSizeFactor(errorNorm: attempt.errorNorm, tolerance: tolerance)
                h = min(hCap, max(hFloor, h * factor))
            } else {
                let factor = stepSizeFactor(errorNorm: attempt.errorNorm, tolerance: tolerance)
                let newH = max(hFloor, h * factor)
                if newH <= hFloor, h <= hFloor {
                    return segments
                }
                h = newH
            }
        }

        return segments
    }

    /// Cubic-Hermite interpolation at `t` against `segments`. Returns
    /// `initialState` if `t` falls before any segment, the last segment's
    /// `endState` if `t` falls past every segment.
    ///
    /// Bisection finds the bracketing segment in `O(log n)` per query.
    private static func interpolate<State: NormedVectorState>(
        at t: Double,
        segments: [Segment<State>],
        initialState: State
    ) -> State where State.Scalar == Double, State: Sendable {
        guard let first = segments.first else { return initialState }
        if t <= first.startTime { return initialState }
        guard let last = segments.last else { return initialState }
        if t >= last.endTime { return last.endState }

        var lo = 0
        var hi = segments.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if segments[mid].endTime < t {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        let segment = segments[lo]
        if t == segment.startTime { return segment.startState }
        if t == segment.endTime { return segment.endState }
        return cubicHermite(at: t, on: segment)
    }

    /// Standard adaptive-step controller: shrink/grow `h` by
    /// `0.9 * (tolerance / error)^(1/5)`, clamped to `[0.1, 5]` so a single
    /// rough step can't cut `h` by orders of magnitude or grow it past the
    /// next problematic region.
    ///
    /// The `0.9` safety factor keeps the next attempt comfortably below the
    /// tolerance threshold; the `^(1/5)` exponent matches the 5th-order
    /// accuracy of the method (a step `h/2` reduces error by `(1/2)^5`).
    private static func stepSizeFactor(errorNorm: Double, tolerance: Double) -> Double {
        guard errorNorm > 0 else { return 5.0 }
        let raw = 0.9 * pow(tolerance / errorNorm, 0.2)
        return min(5.0, max(0.1, raw))
    }
}
