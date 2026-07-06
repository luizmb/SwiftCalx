// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import RungeKutta
import XCTest

final class RungeKutta4TrajectoryTests: XCTestCase {
    func testTrajectoryIncludesInitialState() {
        let trajectory = RungeKutta4.trajectory(
            from: [1.0, 2.0, 3.0],
            derivative: { _, y in y.map { _ in 0 } },
            step: 0.1,
            through: 1.0
        )
        XCTAssertEqual(trajectory.first?.time, 0)
        XCTAssertEqual(trajectory.first?.state, [1, 2, 3])
    }

    func testTrajectoryLengthMatchesStride() {
        let trajectory = RungeKutta4.trajectory(
            from: [0.0],
            derivative: { _, _ in [0] },
            step: 0.1,
            through: 1.0
        )
        // initial state + stride(0.1, 0.2, …, 1.0) = 1 + 10 = 11.
        XCTAssertEqual(trajectory.count, 11)
        XCTAssertEqual(trajectory.last?.time ?? 0, 1.0, accuracy: 1e-12)
    }

    func testTrajectoryOnBatemanTwoCompartment() throws {
        // a → b with rate k=0.1, a(0)=1, b(0)=0. Closed form: a(t) = e^{-kt}, b(t) = 1 - a(t).
        let k = 0.1
        let trajectory = RungeKutta4.trajectory(
            from: [1.0, 0.0],
            derivative: { _, y in [-k * y[0], k * y[0]] },
            step: 0.1,
            through: 10.0
        )
        let last = try XCTUnwrap(trajectory.last)
        XCTAssertEqual(last.time, 10.0, accuracy: 1e-12)
        XCTAssertEqual(last.state[0], exp(-k * 10), accuracy: 1e-10)
        XCTAssertEqual(last.state[1], 1 - exp(-k * 10), accuracy: 1e-10)
    }
}
