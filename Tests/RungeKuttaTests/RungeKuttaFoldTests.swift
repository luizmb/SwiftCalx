// SPDX-License-Identifier: Apache-2.0

import Math
@testable import RungeKutta
import Testing

private let derivative: @Sendable (Double, [Double]) -> [Double] = { _, y in [-0.5 * y[0], 0.3 * y[0] - 0.2 * y[1]] }
private let scalarDerivative: @Sendable (BidimensionalPoint<Double>) -> Double = { point in point.x - point.y }

@Suite("Runge–Kutta folds in place")
struct RungeKuttaFoldTests {
    @Test func stateMutFoldMatchesThePureFold() {
        let step = RungeKutta4.rk4(derivative)
        let pure = stride(from: 0.1, through: 3, by: 0.1)
            .reduce([(time: 0.0, state: [1.0, 0])], RungeKutta4.calculateNextState(Δt: 0.1, stepCalculator: step))
        let inPlace = stride(from: 0.1, through: 3, by: 0.1)
            .reduce(into: [(time: 0.0, state: [1.0, 0])], RungeKutta4.calculateNextStateMut(Δt: 0.1, stepCalculator: step))
        #expect(inPlace.map(\.time) == pure.map(\.time))
        #expect(inPlace.map(\.state) == pure.map(\.state))
    }

    @Test func pointMutFoldMatchesThePureFold() {
        let step = RungeKutta4.rk4(scalarDerivative)
        let start = [BidimensionalPoint(x: 0.0, y: 1.0)]
        let pure = stride(from: 0.1, through: 3, by: 0.1)
            .reduce(start, RungeKutta4.calculateNextPoint(Δx: 0.1, stepCalculator: step))
        let inPlace = stride(from: 0.1, through: 3, by: 0.1)
            .reduce(into: start, RungeKutta4.calculateNextPointMut(Δx: 0.1, stepCalculator: step))
        #expect(inPlace == pure)
    }

    @Test func emptyTrajectoriesStayEmpty() {
        var points: [BidimensionalPoint<Double>] = []
        RungeKutta4.calculateNextPointMut(Δx: 0.1, stepCalculator: RungeKutta4.rk4(scalarDerivative))(&points, 0)
        #expect(points.isEmpty)
        #expect(RungeKutta4.calculateNextState(Δt: 0.1, stepCalculator: RungeKutta4.rk4(derivative))([], 0).isEmpty)
    }

    @Test func pureHelperAppendsToAHandedOverTrajectory() {
        var start: [BidimensionalPoint<Double>] = []
        start.reserveCapacity(8)
        start.append(BidimensionalPoint(x: 0, y: 1))
        let before = start.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) }
        let next = RungeKutta4.calculateNextPoint(Δx: 0.1, stepCalculator: RungeKutta4.rk4(scalarDerivative))(consume start, 0)
        #expect(next.count == 2)
        #expect(next.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) } == before)
    }
}
