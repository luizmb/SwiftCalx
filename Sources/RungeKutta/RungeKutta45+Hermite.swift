// SPDX-License-Identifier: Apache-2.0

import Math

public extension RungeKutta45 {
    /// One accepted Dormand–Prince step, with the slopes at both endpoints kept.
    ///
    /// Those slopes are what makes 4th-order cubic-Hermite interpolation between
    /// the endpoints possible — they're a strict superset of what the bare
    /// `(t, y)` pair gives you, and the integrator already computes them
    /// (`k1 = f(t, y)` at the start of every step, `k7 = f(t + h, y₅) = kLast`
    /// at the end via FSAL).
    ///
    /// The dense-output `RungeKutta45.trajectory(at:from:derivative:…)` driver
    /// keeps a list of these segments while integrating; afterwards, each
    /// requested output time finds its bracketing segment by bisection and
    /// evaluates the cubic-Hermite polynomial.
    struct Segment<State: NormedVectorState>: Sendable
    where State.Scalar == Double, State: Sendable {
        public let startTime: Double
        public let endTime: Double
        public let startState: State
        public let endState: State
        public let startSlope: State
        public let endSlope: State

        public var stepSize: Double { endTime - startTime }

        public init(
            startTime: Double,
            endTime: Double,
            startState: State,
            endState: State,
            startSlope: State,
            endSlope: State
        ) {
            self.startTime = startTime
            self.endTime = endTime
            self.startState = startState
            self.endState = endState
            self.startSlope = startSlope
            self.endSlope = endSlope
        }
    }

    /// Cubic-Hermite interpolant evaluated at absolute time `t` inside this
    /// segment's `[startTime, endTime]`.
    ///
    /// Given two endpoints `(t₀, y₀, m₀)` and `(t₁, y₁, m₁)` with `h = t₁ − t₀`
    /// and local parameter `θ = (t − t₀) / h`, the cubic Hermite polynomial is
    ///
    ///   y(θ) = h₀₀(θ)·y₀ + h₁₀(θ)·h·m₀ + h₀₁(θ)·y₁ + h₁₁(θ)·h·m₁
    ///
    /// with the four basis polynomials
    ///
    ///   h₀₀(θ) =  2θ³ − 3θ² + 1     (endpoint y₀)
    ///   h₁₀(θ) =     θ³ − 2θ² + θ   (slope m₀)
    ///   h₀₁(θ) = −2θ³ + 3θ²         (endpoint y₁)
    ///   h₁₁(θ) =     θ³ −  θ²       (slope m₁)
    ///
    /// At θ = 0 it returns `y₀` exactly; at θ = 1 it returns `y₁` exactly.
    /// Smooth and `C¹`-continuous across segment boundaries because adjacent
    /// segments share endpoint *and* slope.
    ///
    /// Accuracy: 4th-order locally (error `O(h⁴)`). RK45 itself is 5th-order,
    /// so cubic Hermite is one order short of the integrator. For applications
    /// that need to match the 5th-order accuracy of RK45, the standard fix is
    /// Dormand–Prince's published 5th-order continuous extension (uses all 7
    /// stage slopes, not just the two endpoints). Cubic Hermite is the simpler
    /// default; the 5th-order extension is a follow-up.
    ///
    /// References:
    /// - Hairer, Nørsett, Wanner. *Solving Ordinary Differential Equations I:
    ///   Nonstiff Problems*, 2nd ed., §II.6.
    /// - https://en.wikipedia.org/wiki/Cubic_Hermite_spline
    static func cubicHermite<State: NormedVectorState>(
        at t: Double,
        on segment: Segment<State>
    ) -> State where State.Scalar == Double, State: Sendable {
        let h = segment.stepSize
        guard h > 0 else { return segment.startState }
        let theta = (t - segment.startTime) / h
        let theta2 = theta * theta
        let theta3 = theta2 * theta
        let h00 = 2 * theta3 - 3 * theta2 + 1
        let h10 = theta3 - 2 * theta2 + theta
        let h01 = -2 * theta3 + 3 * theta2
        let h11 = theta3 - theta2

        let term0 = h00 * segment.startState
        let term1 = h01 * segment.endState
        let term2 = (h10 * h) * segment.startSlope
        let term3 = (h11 * h) * segment.endSlope
        return term0 + term1 + term2 + term3
    }
}
