// SPDX-License-Identifier: Apache-2.0

import Calculus
import Math
import RealNumber

public extension RungeKutta4 {
    /// Vector-state RK4. The derivative depends on the whole state vector at each
    /// substep, which is required for coupled ODE systems — multi-compartment
    /// biokinetic models, harmonic oscillators, predator–prey, anything where
    /// `dyᵢ/dt` depends on more than just `yᵢ`.
    ///
    /// Returns a step function `(t, y, Δt) → Δy`. The Δ is a *pure delta* — callers
    /// add `y + Δy` (e.g. via ``calculateNextState(Δt:stepCalculator:)``).
    ///
    /// Generic over any ``VectorState`` — built-in conformances cover `Array<T>` for
    /// `T: ℝ` (the typical biokinetic case) and the concrete real-number types
    /// themselves (so the scalar overload above could equivalently be implemented
    /// in terms of this one — kept separate for ergonomic `BidimensionalPoint` use).
    @inlinable
    static func rk4<State: VectorState>(
        _ fn: @escaping (State.Scalar, State) -> State
    ) -> ( /* t */ State.Scalar, /* y */ State, /* Δt */ State.Scalar) -> State {
        { t, y, Δt in
            let half: State.Scalar = Δt / 2
            let k1 = fn(t, y)
            let k2 = fn(t + half, offset(y, by: k1, scaledBy: half))
            let k3 = fn(t + half, offset(y, by: k2, scaledBy: half))
            let k4 = fn(t + Δt, offset(y, by: k3, scaledBy: Δt))
            return SimpsonWeightedAverage.calculate(Δt * k1, Δt * k2, Δt * k3, Δt * k4)
        }
    }

    /// `y + scalar * k` as one new state.
    @inlinable
    internal static func offset<State: VectorState>(_ y: State, by k: State, scaledBy scalar: State.Scalar) -> State {
        var result = y
        result.add(k, scaledBy: scalar)
        return result
    }

    /// Reduce-shaped helper that appends the next `(time, state)` pair to the trajectory.
    /// Use as the closure passed to `stride(...).reduce(...)`.
    ///
    /// Each call returns a new array, so a fold over `n` steps copies `O(n²)` points in
    /// total. For long runs use ``trajectory(from:derivative:step:through:)``, which
    /// appends in place.
    @inlinable
    static func calculateNextState<State: VectorState>(
        Δt: State.Scalar,
        stepCalculator: @escaping (State.Scalar, State, State.Scalar) -> State
    ) -> (
        [(time: State.Scalar, state: State)],
        State.Scalar
    ) -> [(time: State.Scalar, state: State)] {
        { points, _ in
            guard let last = points.last else { return [] }
            let Δy = stepCalculator(last.time, last.state, Δt)
            return points + [(time: last.time + Δt, state: last.state + Δy)]
        }
    }
}
