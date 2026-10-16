// SPDX-License-Identifier: Apache-2.0

public extension RungeKutta45 {
    /// Why an adaptive integration stopped before the end of its span, with what it computed before
    /// stopping.
    ///
    /// `partial` covers only the span the integrator reached, up to `reachedTime`: no state past it
    /// exists, so nothing is held or extrapolated for the times it didn't reach. What is there is as
    /// accurate as a finished run. ``trajectory(at:from:derivative:startingAt:tolerance:initialStep:minStep:maxStep:maxIterations:)``
    /// carries the states for the leading output times up to `reachedTime`;
    /// ``denseSegments(from:derivative:startingAt:through:tolerance:initialStep:minStep:maxStep:maxIterations:)``
    /// the segments it accepted.
    enum Failure<Partial: Sendable>: Error, Sendable {
        /// The `maxIterations` budget (accepted + rejected steps) ran out at time `reached`.
        /// Typical on stiff systems, where an explicit method is held near its stability limit:
        /// raise the budget in proportion to the span times the fastest rate.
        case stepLimit(reached: Double, steps: Int, partial: Partial)
        /// The controller asked for a step below `minStep` at time `at`.
        case stepUnderflow(at: Double, step: Double, partial: Partial)

        /// How far the integration got.
        public var reachedTime: Double {
            switch self {
            case let .stepLimit(reached, _, _): reached
            case let .stepUnderflow(at, _, _): at
            }
        }

        /// What was computed before the stop.
        public var partial: Partial {
            switch self {
            case let .stepLimit(_, _, partial): partial
            case let .stepUnderflow(_, _, partial): partial
            }
        }

        /// The same stop, with what was computed transformed.
        public func mapPartial<T: Sendable>(_ transform: (Partial) -> T) -> Failure<T> {
            switch self {
            case let .stepLimit(reached, steps, partial): .stepLimit(reached: reached, steps: steps, partial: transform(partial))
            case let .stepUnderflow(at, step, partial): .stepUnderflow(at: at, step: step, partial: transform(partial))
            }
        }
    }
}

extension RungeKutta45.Failure: Equatable where Partial: Equatable {}
