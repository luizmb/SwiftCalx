// SPDX-License-Identifier: Apache-2.0

import Calculus
import Math
import RealNumber
@testable import RungeKutta
import Testing

// The solvers build each stage in place. These pin them to the operator formulas they
// replace, bit for bit, so the speed-up can't move a result.

private let decay = Matrix<Double>(rows: 3, columns: 3, storage: [-0.5, 0, 0.02, 0.4, -0.7, 0, 0.01, 0.3, -0.9])
private let derivative: @Sendable (Double, [Double]) -> [Double] = { _, y in decay.apply(to: y) }
private let y0 = [1.0, 0.25, -0.5]

@Suite("Runge–Kutta stages match the operator formulas")
struct RungeKuttaInPlaceTests {
    @Test func simpsonMatchesTheOperatorFormula() {
        let v = [[0.1, 0.2, 0.3], [1.1, -0.4, 0.7], [0.9, 0.05, -2.2], [3.3, 1.7, 0.01]]
        let expected = (1 / 6.0) * (v[0] + 2 * v[1] + 2 * v[2] + v[3])
        #expect(SimpsonWeightedAverage.calculate(v[0], v[1], v[2], v[3]) == expected)
    }

    @Test func rk4StepMatchesTheOperatorFormula() {
        let (t, Δt) = (0.3, 0.05)
        let half = Δt / 2
        let k1 = derivative(t, y0)
        let k2 = derivative(t + half, y0 + half * k1)
        let k3 = derivative(t + half, y0 + half * k2)
        let k4 = derivative(t + Δt, y0 + Δt * k3)
        let expected = (1 / 6.0) * (Δt * k1 + 2 * (Δt * k2) + 2 * (Δt * k3) + Δt * k4)
        #expect(RungeKutta4.rk4(derivative)(t, y0, Δt) == expected)
    }

    @Test func rk4TrajectoryMatchesTheCalculateNextStateFold() {
        let fold = stride(from: 0.1, through: 5, by: 0.1).reduce(
            [(time: 0.0, state: y0)],
            RungeKutta4.calculateNextState(Δt: 0.1, stepCalculator: RungeKutta4.rk4(derivative))
        )
        let trajectory = RungeKutta4.trajectory(from: y0, derivative: derivative, step: 0.1, through: 5)
        #expect(trajectory.map(\.time) == fold.map(\.time))
        #expect(trajectory.map(\.state) == fold.map(\.state))
    }

    @Test func rk45StepMatchesTheOperatorFormula() {
        let (t, h) = (0.2, 0.1)
        let k1 = derivative(t, y0)
        let k2 = derivative(t + h / 5, y0 + (h / 5) * k1)
        let k3 = derivative(t + 3 * h / 10, y0 + (h * 3 / 40) * k1 + (h * 9 / 40) * k2)
        let k4 = derivative(t + 4 * h / 5, y0 + (h * 44 / 45) * k1 + (h * -56 / 15) * k2 + (h * 32 / 9) * k3)
        let s5 = y0 + (h * (19_372.0 / 6_561)) * k1 + (h * (-25_360.0 / 2_187)) * k2 + (h * (64_448.0 / 6_561)) * k3
        let k5 = derivative(t + 8 * h / 9, s5 + (h * (-212.0 / 729)) * k4)
        let s6 = y0 + (h * (9_017.0 / 3_168)) * k1 + (h * (-355.0 / 33)) * k2 + (h * (46_732.0 / 5_247)) * k3
        let k6 = derivative(t + h, s6 + (h * (49.0 / 176)) * k4 + (h * (-5_103.0 / 18_656)) * k5)
        let y5a = y0 + (h * (35.0 / 384)) * k1 + (h * (500.0 / 1_113)) * k3 + (h * (125.0 / 192)) * k4
        let y5 = y5a + (h * (-2_187.0 / 6_784)) * k5 + (h * (11.0 / 84)) * k6
        let k7 = derivative(t + h, y5)
        let y4a = y0 + (h * (5_179.0 / 57_600)) * k1 + (h * (7_571.0 / 16_695)) * k3 + (h * (393.0 / 640)) * k4
        let y4 = y4a + (h * (-92_097.0 / 339_200)) * k5 + (h * (187.0 / 2_100)) * k6 + (h * (1.0 / 40)) * k7

        let step = RungeKutta45.step(from: t, y: y0, k1: k1, size: h, derivative: derivative)
        #expect(step.y5 == y5)
        #expect(step.y4 == y4)
        #expect(step.kLast == k7)
        #expect(step.errorNorm == (y5 + -1.0 * y4).infinityNorm)
    }

    @Test func cubicHermiteMatchesTheOperatorFormula() {
        let segment = RungeKutta45.Segment(
            startTime: 1,
            endTime: 1.5,
            startState: [1.0, 2.0],
            endState: [0.5, 2.5],
            startSlope: [-1.0, 0.75],
            endSlope: [-0.5, 1.25]
        )
        let (h, θ) = (0.5, (1.15 - 1) / 0.5)
        let (θ2, θ3) = (θ * θ, θ * θ * θ)
        let h00: Double = 2 * θ3 - 3 * θ2 + 1
        let h01: Double = -2 * θ3 + 3 * θ2
        let h10: Double = θ3 - 2 * θ2 + θ
        let h11: Double = θ3 - θ2
        let terms: [[Double]] = [
            h00 * segment.startState,
            h01 * segment.endState,
            (h10 * h) * segment.startSlope,
            (h11 * h) * segment.endSlope
        ]
        let expected = terms[0] + terms[1] + terms[2] + terms[3]
        #expect(RungeKutta45.cubicHermite(at: 1.15, on: segment) == expected)
    }
}
