// SPDX-License-Identifier: Apache-2.0

import Math
import RealNumber

public extension RungeKutta4 {
    /// Integrate a vector-state ODE `dy/dt = f(t, y)` from `t = 0` to `t = end` using
    /// a fixed RK4 step of size `step`, returning the full `(time, state)` trajectory.
    ///
    /// This is the **default driver** for one-shot integration: build the step closure
    /// via ``rk4(_:)``, the appender via ``calculateNextState(Δt:stepCalculator:)``,
    /// then fold over `stride(from: step, through: end, by: step)`. The starting
    /// `(0, initialState)` is included as the first element of the result.
    ///
    /// Callers that want a different sampling cadence (e.g. record every Nth RK4
    /// step rather than every step) should sub-sample the returned array — `step`
    /// here is the *RK4 step size*, not an output cadence.
    ///
    /// `State` is generic over any ``VectorState``; the scalar must be `Double` so
    /// `stride(...)` works (`State.Scalar` is not required to be `Strideable` in
    /// general). For non-`Double` scalars, write the equivalent fold by hand.
    static func trajectory<State: VectorState>(
        from initialState: State,
        derivative: @escaping (Double, State) -> State,
        step: Double,
        through end: Double
    ) -> [(time: Double, state: State)] where State.Scalar == Double {
        let advance = calculateNextState(Δt: step, stepCalculator: rk4(derivative))
        return stride(from: step, through: end, by: step).reduce(
            [(time: 0.0, state: initialState)],
            advance
        )
    }
}
