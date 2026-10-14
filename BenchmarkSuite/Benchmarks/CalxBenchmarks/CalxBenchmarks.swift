import Benchmark
import Calculus
import Math
import MathOperators
import RealNumber
import RungeKutta

// Hot paths of the matrix and ODE code, measured in time, instructions, mallocs and
// retains/releases. Compare a change with `swift package benchmark baseline update <name>`
// before and after, then `baseline compare`.
//
// Run once as is (Apple: the Accelerate overloads) and once with
// `-Xswiftc -DSWIFTCALX_NO_ACCELERATE` (the generic Swift loops Linux, Windows and Android use).
//
// `generic` rows call through code that only knows `Scalar: ℝ` (the `⋅` operator,
// `Matrix.Product`, `squared(times:)`, anything generic in an app), so they never see the
// `Scalar == Double` overloads.

func config() -> Benchmark.Configuration {
    Benchmark.Configuration(
        metrics: [.wallClock, .instructions, .mallocCountTotal, .retainCount, .releaseCount],
        units: [.instructions: .count, .mallocCountTotal: .count, .retainCount: .count, .releaseCount: .count],
        maxDuration: .seconds(2)
    )
}

/// A deterministic, well-conditioned `n × n` matrix: a decay chain (each compartment drains into
/// the next), the shape of a biokinetic model.
func decayChain(_ n: Int) -> Matrix<Double> {
    Matrix(rows: n, columns: n, storage: (0 ..< n * n).map { index in
        let (i, j) = (index / n, index % n)
        return i == j ? -0.5 - Double(i) / Double(n) : i == j + 1 ? 0.4 : 0.01 * Double((i + j) % 3)
    })
}

@inline(never) func genericProduct<S: ℝ>(_ lhs: Matrix<S>, _ rhs: Matrix<S>) -> Matrix<S> {
    lhs * rhs
}

@inline(never) func genericSum<S: ℝ>(_ lhs: Matrix<S>, _ rhs: Matrix<S>) -> Matrix<S> {
    lhs + rhs
}

let benchmarks: @Sendable () -> Void = {
    for n in [4, 16, 64] {
        let a = decayChain(n)
        let b = decayChain(n)
        Benchmark("matrix * matrix, Double (\(n)×\(n))", configuration: config()) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(a * b)
            }
        }
        Benchmark("matrix * matrix, generic (\(n)×\(n))", configuration: config()) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(genericProduct(a, b))
            }
        }
        Benchmark("matrix + matrix, Double (\(n)×\(n))", configuration: config()) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(a + b)
            }
        }
        Benchmark("matrix + matrix, generic (\(n)×\(n))", configuration: config()) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(genericSum(a, b))
            }
        }
        Benchmark("matrix += matrix (\(n)×\(n))", configuration: config()) { benchmark in
            var acc = Matrix(rows: n, columns: n, storage: a.storage.map { $0 })
            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                acc += b
            }
            benchmark.stopMeasurement()
            blackHole(acc)
        }
        Benchmark("matrix *= scalar (\(n)×\(n))", configuration: config()) { benchmark in
            var acc = Matrix(rows: n, columns: n, storage: a.storage.map { $0 })
            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                acc *= 1.0
            }
            benchmark.stopMeasurement()
            blackHole(acc)
        }
        let vector = (0 ..< n).map(Double.init)
        Benchmark("matrix · vector, Double (\(n)×\(n))", configuration: config()) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(a.apply(to: vector))
            }
        }
    }

    let a16 = decayChain(16)
    Benchmark("matrix ⋅ matrix operator (16×16)", configuration: config()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(a16 ⋅ a16)
        }
    }
    Benchmark("squared(times: 6) (16×16)", configuration: config()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole((0.01 * a16).squared(times: 6))
        }
    }
    Benchmark("Taylor.exponential (16×16)", configuration: config()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Taylor.exponential(of: a16))
        }
    }
    // Birchall's scaling-and-squaring as BiokineticsDosimetry runs it: scale by 2⁻ᵏ, Taylor
    // series, square k times.
    let k = 10
    Benchmark("Birchall e^A: scale, Taylor, squared(times: 10) (16×16)", configuration: config()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Taylor.exponential(of: (1 / Double(1 << k)) * (4 * a16)).squared(times: k))
        }
    }
    Benchmark("actions(on:count: 1000) (16×16)", configuration: config()) { benchmark in
        let y0 = [Double](repeating: 1, count: 16)
        for _ in benchmark.scaledIterations {
            blackHole(a16.actions(on: y0, count: 1_000))
        }
    }

    let x = (0 ..< 16).map(Double.init)
    let y = (0 ..< 16).map { Double($0) * 2 }
    Benchmark("[Double] + [Double] (16)", configuration: config()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(x + y)
        }
    }
    Benchmark("scalar * [Double] (16)", configuration: config()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(2.0 * x)
        }
    }

    // Linear ODE dy/dt = A·y, 16 compartments.
    let derivative: @Sendable (Double, [Double]) -> [Double] = { _, y in a16.apply(to: y) }
    let accelerated: @Sendable (Double, AcceleratedVector) -> AcceleratedVector = { _, y in a16.apply(to: y) }
    let y0 = [Double](repeating: 1, count: 16)

    Benchmark("RK4 trajectory, [Double] (16, 1 000 steps)", configuration: config()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(RungeKutta4.trajectory(from: y0, derivative: derivative, step: 0.01, through: 10))
        }
    }
    Benchmark("RK4 trajectory, Double (1 000 steps)", configuration: config()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(RungeKutta4.trajectory(from: 1.0, derivative: { t, y in -y + t }, step: 0.01, through: 10))
        }
    }
    Benchmark("RK4 step, [Double] (16)", configuration: config()) { benchmark in
        let step = RungeKutta4.rk4(derivative)
        for _ in benchmark.scaledIterations {
            blackHole(step(0, y0, 0.01))
        }
    }
    Benchmark("RK45 step, [Double] (16)", configuration: config()) { benchmark in
        let k1 = derivative(0, y0)
        for _ in benchmark.scaledIterations {
            blackHole(RungeKutta45.step(from: 0, y: y0, k1: k1, size: 0.01, derivative: derivative))
        }
    }
    Benchmark("RK45 trajectory, [Double] (16, 200 outputs)", configuration: config()) { benchmark in
        let times = (1 ... 200).map { Double($0) * 0.05 }
        for _ in benchmark.scaledIterations {
            blackHole(RungeKutta45.trajectory(at: times, from: y0, derivative: derivative, tolerance: 1e-9))
        }
    }
    Benchmark("RK45 trajectory, AcceleratedVector (16, 200 outputs)", configuration: config()) { benchmark in
        let times = (1 ... 200).map { Double($0) * 0.05 }
        let start = AcceleratedVector(y0)
        for _ in benchmark.scaledIterations {
            blackHole(RungeKutta45.trajectory(at: times, from: start, derivative: accelerated, tolerance: 1e-9))
        }
    }
    Benchmark("RK45 trajectory, Double (200 outputs)", configuration: config()) { benchmark in
        let times = (1 ... 200).map { Double($0) * 0.05 }
        for _ in benchmark.scaledIterations {
            blackHole(RungeKutta45.trajectory(at: times, from: 1.0, derivative: { t, y in -y + t }, tolerance: 1e-9))
        }
    }
}
