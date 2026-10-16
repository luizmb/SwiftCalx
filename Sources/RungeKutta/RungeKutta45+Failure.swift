// SPDX-License-Identifier: Apache-2.0

public extension RungeKutta45 {
    /// Why an adaptive integration stopped before the end of its span.
    ///
    /// Either way no state past `reached` / `at` exists: the integrator reports the stop instead of
    /// holding the last state for the remaining output times.
    enum Failure: Error, Equatable, Sendable {
        /// The `maxIterations` budget (accepted + rejected steps) ran out at time `reached`.
        /// Typical on stiff systems, where an explicit method is held near its stability limit:
        /// raise the budget in proportion to the span times the fastest rate.
        case stepLimit(reached: Double, steps: Int)
        /// The controller asked for a step below `minStep` at time `at`.
        case stepUnderflow(at: Double, step: Double)
    }
}
