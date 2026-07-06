# ``SwiftCalx``

A Swift numerical-methods library — ODE solvers, numerical derivatives, matrix arithmetic,
and the algebraic foundations they rest on — built on [luizmb/FP](https://github.com/luizmb/FP).

## Overview

The name comes from Latin *calx*, a small stone used for reckoning — the root of *calculate* and
*calculus*. `SwiftCalx` is split into focused modules so you import only what you need:

| Module | Contents |
|--------|----------|
| `Math` | Vector states, normed vectors, matrices, weighted averages (`Math` includes operators; `MathNoOperators` omits them) |
| `Calculus` | Numerical derivatives and related operations |
| `RungeKutta` | ODE solvers (RK4, RK45) with trajectory generation |
| `RealNumber` | The `ℝ` real-number protocol and conformances (`Double`, `Float`, `Float80`) |
| `SwiftCalx` | Umbrella — re-exports everything |

Everything follows the FP house style: pure functions, values over side effects, `Sendable`-first,
and composition via the FP operator vocabulary.

```swift
import RungeKutta

// dy/dt = y, y(0) = 1, integrated to t = 1 → y(1) ≈ e ≈ 2.718.
// `Double` conforms to VectorState, so a scalar ODE needs no wrapper type.
let path = RungeKutta4.trajectory(from: 1.0, derivative: { _, y in y }, step: 0.01, through: 1.0)
let approxE = path.last?.state   // ≈ 2.718
```

## Topics

### Getting Started
- <doc:GettingStarted>

### Modules

Browse each module's own documentation page: **Math**, **Calculus**, **RungeKutta**, **RealNumber**
(see the module overview table above for what each contains).
