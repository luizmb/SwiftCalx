# Getting Started

Install SwiftCalx, pick the products you need, and solve your first ODE.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/luizmb/SwiftCalx.git", from: "1.1.0")
```

Then add the products you need to your target. Each capability is a separate product so you only
pull in what you use:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "RungeKutta", package: "SwiftCalx"),
    .product(name: "Calculus",   package: "SwiftCalx"),
])
```

Prefer `MathNoOperators` / `CalculusNoOperators` if you want the types without the operator surface.

## Solving an ODE

`RungeKutta4.trajectory` integrates `dy/dt = f(t, y)` with a fixed RK4 step and returns the full
`(time, state)` path. The state is any `VectorState` (from the `Math` module); a plain `Double`
qualifies, so scalar problems need no wrapper.

```swift
import RungeKutta

// Exponential growth: dy/dt = y, y(0) = 1.
let path = RungeKutta4.trajectory(
    from: 1.0,
    derivative: { _, y in y },
    step: 0.01,
    through: 1.0
)

path.first?.state   // 1.0   (the initial state is included)
path.last?.state    // ≈ 2.718  (≈ e)
```

For a vector-valued system, wrap your components in an `AcceleratedVector` (Accelerate-backed)
or use any type conforming to `VectorState`.

## Numerical derivatives

The `Calculus` module differentiates a function numerically. Pair the function with a
`DerivativeMethod` (which finite-difference stencil, and how to pick the step `h`):

```swift
import Calculus

let f = Fn<Double> { x in x * x * x }   // f(x) = x³, so f'(x) = 3x²
let df = DerivativeFunction(
    underlyingFunction: f,
    method: .CentralStencil.fivePoint(order: 1, step: .adaptative)
)

df(x: 2.0)              // ≈ 12
df.slopeFunction(3.0)   // ≈ 27
```

## Matrices and in-place updates

`Matrix` is a row-major matrix over any real scalar. On Apple platforms `Double` and `Float`
products go through Accelerate; elsewhere they run as specialised Swift loops. The compound
operators and the optics write into the matrix's own buffer, so a loop that updates a matrix
allocates nothing:

```swift
import CoreFP
import Math

var a = Matrix<Double>(rows: 2, columns: 2, storage: [1, 2, 3, 4])
a += Matrix<Double>.identity(size: 2)                  // in place
Matrix<Double>.diagonal.modifyMut(&a) { $0 *= 0.5 }   // in place, diagonal only

var product = Matrix<Double>.zero(size: 2)
Matrix.multiply(a, a, into: &product)                  // reuses `product`'s buffer
```

## Next steps

- **Math** — vector states, matrices, matrix optics, weighted averages
- **RungeKutta** — RK4 and adaptive RK45 solvers
- **RealNumber** — the `ℝ` protocol and its conformances
