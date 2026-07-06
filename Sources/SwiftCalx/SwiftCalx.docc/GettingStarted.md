# Getting Started

Install SwiftCalx, pick the products you need, and solve your first ODE.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/luizmb/SwiftCalx.git", from: "0.4.0")
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

The `Calculus` module differentiates a function numerically:

```swift
import Calculus

// See ``Calculus`` for the derivative and Taylor-series APIs.
```

## Next steps

- **Math** — vector states, matrices, weighted averages
- **RungeKutta** — RK4 and adaptive RK45 solvers
- **RealNumber** — the `ℝ` protocol and its conformances
