# SwiftCalx

[![CI](https://github.com/luizmb/SwiftCalx/actions/workflows/ci.yml/badge.svg)](https://github.com/luizmb/SwiftCalx/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/docs-online-blue)](https://ios.lu/SwiftCalx)
[![Swift 6.3+](https://img.shields.io/badge/swift-6.3%2B-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

**[→ Full API Documentation](https://ios.lu/SwiftCalx)** · [Installation](#installation)

A Swift numerical-methods library: ODE solvers, numerical derivatives, matrix arithmetic, and the small algebraic pieces (real numbers, vector states, weighted averages) those rest on. Built on top of [luizmb/FP](https://github.com/luizmb/FP) for composition primitives.

The name is from Latin *calx* — a small stone used for reckoning in ancient Rome. *Calx* is the etymological root of *calculate*, *calculation*, and *calculus*. Romans literally counted with pebbles; this library does the same in floating-point.

## Table of contents

- [What you can do with it](#what-you-can-do-with-it)
- [Installation](#installation)
- [Choosing products](#choosing-products)
- [Foundations](#foundations)
  - [ℝ — real numbers as a protocol](#ℝ--real-numbers-as-a-protocol)
  - [VectorState — a vector you can add and scale](#vectorstate--a-vector-you-can-add-and-scale)
  - [NormedVectorState — vectors with a length](#normedvectorstate--vectors-with-a-length)
  - [BidimensionalPoint and TridimensionalPoint](#bidimensionalpoint-and-tridimensionalpoint)
  - [AcceleratedVector](#acceleratedvector)
- [Matrices](#matrices)
  - [Operations](#operations)
  - [Iterated action — applying a matrix many times](#iterated-action--applying-a-matrix-many-times)
  - [Matrix.Sum and Matrix.Product — folding semigroup-style](#matrixsum-and-matrixproduct--folding-semigroup-style)
  - [Hardware-accelerated mat-vec and mat-mat](#hardware-accelerated-mat-vec-and-mat-mat)
  - [Why "repeated squaring"?](#why-repeated-squaring)
- [Numerical derivatives](#numerical-derivatives)
  - [What is a derivative?](#what-is-a-derivative)
  - [DerivativeMethod — picking a stencil](#derivativemethod--picking-a-stencil)
  - [CentralStencil, ForwardStencil, BackwardStencil](#centralstencil-forwardstencil-backwardstencil)
  - [Richardson extrapolation](#richardson-extrapolation)
  - [Fornberg's algorithm — custom stencils](#fornbergs-algorithm--custom-stencils)
  - [StepCalculator — choosing h](#stepcalculator--choosing-h)
  - [DerivativeFunction — paired function + method](#derivativefunction--paired-function--method)
- [Taylor series for matrices](#taylor-series-for-matrices)
- [Solving differential equations (ODEs)](#solving-differential-equations-odes)
  - [What is an ODE?](#what-is-an-ode)
  - [RungeKutta4 — classical fixed-step solver](#rungekutta4--classical-fixed-step-solver)
  - [RungeKutta45 — Dormand-Prince adaptive solver](#rungekutta45--dormand-prince-adaptive-solver)
    - [Dense output — querying the trajectory at chosen times](#dense-output--querying-the-trajectory-at-chosen-times)
  - [Choosing between RK4 and RK45](#choosing-between-rk4-and-rk45)
  - [SimpsonWeightedAverage — the weighting underneath](#simpsonweightedaverage--the-weighting-underneath)
- [Fibonacci](#fibonacci)
- [Operators](#operators)
- [Logarithms](#logarithms)
- [Numeric utilities](#numeric-utilities)
- [Mathematical symbols](#mathematical-symbols)
- [Concurrency: Sendable-first](#concurrency-sendable-first)
- [Platform support](#platform-support)
- [Roadmap](#roadmap)
- [References](#references)
- [License](#license)

---

## What you can do with it

A few example problems SwiftCalx solves out of the box, with pointers to the relevant sections:

- **Simulate physical systems** — pendulums, harmonic oscillators, predator-prey dynamics, planetary orbits. Anything described by "the rate of change of `y` is some function of `t` and `y`" is an ODE; SwiftCalx integrates it. See [Solving differential equations](#solving-differential-equations-odes).
- **Model radioactive decay or chemical kinetics** — compartmental models like "drug enters bloodstream at rate `k₁`, moves to tissue at rate `k₂`, gets excreted at rate `k₃`". See [RungeKutta4](#rungekutta4--classical-fixed-step-solver) and the Birchall matrix exponential discussion in [Taylor series for matrices](#taylor-series-for-matrices).
- **Compute slopes of functions you only know numerically** — when you have data points or a function you can only evaluate, but no symbolic derivative. See [Numerical derivatives](#numerical-derivatives).
- **Work with vectors and matrices** — addition, scalar multiplication, matrix-matrix and matrix-vector products, repeated squaring. See [Matrices](#matrices).
- **Solve "find x such that f(x) = 0"** — root finding (planned; see [Roadmap](#roadmap)).
- **Combine numerical methods compositionally** — every algorithm is a Swift value (a `DerivativeMethod`, a `Step`, a trajectory); they compose like building blocks.

The library targets **students, scientific Swift developers, and educators** — both for getting work done and for learning how the underlying algorithms work. Every public type has docstrings explaining the math; every algorithm cites the canonical reference.

---

## Installation

Swift Package Manager. In your `Package.swift`:

```swift
.package(url: "https://github.com/luizmb/SwiftCalx.git", from: "0.4.0")
```

Then pick a product for each target that needs it:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "SwiftCalx", package: "SwiftCalx") // umbrella: everything
        // — or pick à la carte: —
        // .product(name: "Math", package: "SwiftCalx"),
        // .product(name: "Calculus", package: "SwiftCalx"),
        // .product(name: "RungeKutta", package: "SwiftCalx"),
    ]
)
```

## Choosing products

| Product | Pulls in | Use this when |
|---|---|---|
| `Math` | `Math` + `MathOperators` | You want matrices and vectors with the `⋅` operator. |
| `MathNoOperators` | `Math` only | Same but you don't want any custom operators in scope. |
| `Calculus` | `Calculus` + `MathOperators` | You want derivatives, Taylor, Fibonacci. |
| `CalculusNoOperators` | `Calculus` only | Calculus without custom operators. |
| `RungeKutta` | `RungeKutta` + `MathOperators` | You want ODE solvers (which use matrices, hence the operators). |
| `SwiftCalx` | All of the above | You want everything; one-line `import SwiftCalx`. |

The `*NoOperators` variants exist for projects that want strict control over global operator declarations (e.g. when interop with another library that defines conflicting operators is needed).

---

## Foundations

These are the smallest building blocks every other module uses. Skim if you're in a hurry; understand them deeply if you intend to write custom numerical code on top.

### ℝ — real numbers as a protocol

In math, ℝ is the symbol for "the real numbers" — the set of all decimal numbers, including integers, fractions, irrationals like π and √2, and limits of converging sequences.

In SwiftCalx, `ℝ` (also typealiased as `Real`) is a **protocol**: a contract describing what an algorithm needs from "a numeric type". Stdlib types `Double`, `Float`, `Decimal`, `Float16`, `Float80` all conform; you can write your own conformer (e.g. a fixed-point or arbitrary-precision type) and every algorithm here will accept it.

```swift
public protocol ℝ: SignedNumeric, Comparable, Sendable {
    static var epsilon: Self { get }
    static func / (_ a: Self, _ b: Self) -> Self
    var isNaN: Bool { get }
    func raisedToThePower(of exponent: Self) -> Self
    static func random<T: RandomNumberGenerator>(in range: Range<Self>, using generator: inout T) -> Self
    func isMultiple(of number: Self, tolerance: Self) -> Bool
    static var notANumber: Self { get }
    static func eⁿ(_ n: Self) -> Self
    static var e: Self { get }
    var sign: FloatingPointSign { get }
    func squareRoot() -> Self
}
```

The requirements are intentionally **what numerical methods actually need** — division, NaN detection, exponentiation, the constant `e`, and the square root. Methods like RK4 are generic over `T: ℝ`, which is how they work for `Double` and `Decimal` and your custom type all from the same code.

Convenience methods on `ℝ` (via extension):

- `cubeRoot()` — `self^(1/3)`. Falls back to `nRoot(degree: 3)`.
- `nRoot(degree:)` — n-th root via `raisedToThePower(of: 1/degree)`. Returns NaN for negative bases under even degrees (because Swift's `pow(-h, 1/3)` returns NaN even for the mathematically defined real cube root of −h; this is a floating-point limitation, not a SwiftCalx choice).
- `isMultiple(of:)` — without a tolerance argument, defaults to exact equality.

**Use cases**: writing generic numerical code that works across precisions; mixing `Double` for speed in production with `Decimal` for accuracy in tests; supplying your own `BigDecimal` for arbitrary-precision financial calculations.

**Read more**: [Wikipedia — Real number](https://en.wikipedia.org/wiki/Real_number).

### VectorState — a vector you can add and scale

A "state" in physics or engineering is just a list of numbers that describes a system at one moment: a particle's position and velocity (4 numbers in 2D, 6 in 3D); a chemical reactor's species concentrations (one per species); a multi-compartment biokinetic model's activities (one per compartment).

To evolve a state through time (which is what ODE solvers do), you need two operations:

1. **Add two states** — `state1 + state2` — combining two contributions to a change.
2. **Scale a state** — `Δt · derivative` — multiplying a vector of slopes by a small time step to get a vector of position changes.

That's the entire contract of `VectorState`:

```swift
public protocol VectorState: Sendable {
    associatedtype Scalar: ℝ
    static func + (lhs: Self, rhs: Self) -> Self
    static func * (scalar: Scalar, state: Self) -> Self
}
```

Built-in conformances:

- **`Array<Element>`** where `Element: ℝ` — element-wise addition, element-wise scalar multiplication. The natural way to spell an n-dimensional state vector.
- **`Double`, `Float`, `Decimal`, `Float16`, `Float80`** — every concrete ℝ type is its own one-dimensional vector space, with `Scalar == Self`. This lets the same algorithm code drive both scalar and vector solvers.

In math language, `VectorState` describes a *vector space over the scalar ring* — but you don't need to know that to use it. Just think: "states I can add and stretch".

**Use cases**: any multi-component simulation. Particle systems, ecosystems, compartmental models, neural-network forward passes, signal-processing buffers.

**Read more**: [Wikipedia — Vector space](https://en.wikipedia.org/wiki/Vector_space).

### NormedVectorState — vectors with a length

For adaptive ODE solvers like Dormand-Prince ([`RungeKutta45`](#rungekutta45--dormand-prince-adaptive-solver)), the integrator needs to **measure how big the error is** at each step, so it knows whether to accept the step and how to size the next one. "How big is a vector?" is a norm.

SwiftCalx uses the **infinity norm** — the maximum absolute value across components — as the standard choice. It's the simplest well-behaved norm: no sums of squares (which can overflow on big states), no floating-point sqrt (which can lose precision near zero), and component-by-component meaning. If one compartment of a 100-compartment biokinetic model is off by 0.01 and the rest are perfect, the infinity norm tells you "error is 0.01" rather than dividing it across 100.

```swift
public protocol NormedVectorState: VectorState {
    var infinityNorm: Scalar { get }
}
```

Built-in conformances: same as `VectorState` (so an `Array<Element: ℝ>` has `infinityNorm = max |elements|`, a `Double` has `infinityNorm = magnitude`).

**Use cases**: anything that needs an error tolerance — adaptive ODE solvers, iterative root-finding, optimisation convergence checks.

**Read more**: [Wikipedia — Norm (mathematics)](https://en.wikipedia.org/wiki/Norm_(mathematics)), especially the infinity-norm section.

### BidimensionalPoint and TridimensionalPoint

Plain value types for 2D and 3D points over any `ℝ`. Both ship full **vector-space arithmetic** (addition, subtraction, scalar multiplication, `.zero`), conform to ``VectorState`` so they can flow through ODE solvers like any other state, and conform directly to FP's ``Monoid`` under elementwise addition (origin is identity).

```swift
let p = BidimensionalPoint(x: 1.0, y: 2.0)
let q = BidimensionalPoint(x: 4.0, y: 6.0)

p.slope(to: q)        // 1.333… — slope of the line through p and q
p + q                 // (5, 8)
q - p                 // (3, 4)
2.0 * p               // (2, 4)
BidimensionalPoint<Double>.zero            // (0, 0) — origin / Monoid identity

// Fold a sequence with FP's mconcat (uses combine = +, identity = .zero)
import CoreFP
let centroidSum: BidimensionalPoint<Double> = mconcat([
    BidimensionalPoint(x: 1, y: 2),
    BidimensionalPoint(x: 3, y: 4),
    BidimensionalPoint(x: 5, y: 6),
])   // (9, 12)
```

`slope(to:)` returns `Δy / Δx`. If `Δx == 0` (a vertical line) it returns `0` rather than crashing, on the principle "no vertical-tangent fatal errors in numerical code"; check `Δx` yourself if you need to distinguish a vertical line from a flat one.

The scalar `rk4` overload of [`RungeKutta4`](#rungekutta4--classical-fixed-step-solver) takes a `BidimensionalPoint` because that's the natural shape for a single `(time, value)` pair in 1D ODE integration. The vector overload uses any `VectorState` for higher dimensions.

`TridimensionalPoint` is the obvious 3D version with the same arithmetic + Monoid story; useful for 3D trajectories.

**Why direct `Monoid` conformance, not a `.Sum` wrapper?** A point only has one canonical Monoid (additive — scalar `*` has signature `(T, Point) → Point`, which is a vector-space scalar action, not a Monoid operation on `Point`). The same reason FP conforms `String` and `Array` directly to `Monoid` rather than wrapping them: there's no competing operation to disambiguate against. Compare to `Matrix`, which has *two* natural operations (addition and multiplication), so it ships [`Matrix.Sum` / `Matrix.Product`](#matrices) newtypes instead.

**Use cases**: ODE integration plots, geometric calculations, slope-of-line algorithms, summing positions or velocities across particles.

### AcceleratedVector

`AcceleratedVector` is a concrete `[Double]`-backed value type that exists for one reason: to be the **opt-in fast state type** for the solvers. Wrapping your `[Double]` once at the entry point lets every per-stage `+` and `*` along the integration trajectory route through hand-tuned BLAS / vDSP kernels on Apple platforms — automatically, through the protocol witness for `VectorState`.

The name is deliberately blunt about what the type is: a hardware-accelerated, `Double`-only, vector-shaped storage. **It's not the general mathematical "vector" abstraction** — that's `Array<T>` where `T: ℝ`, which already conforms to `VectorState` and represents the abstraction of a vector over any computable approximation of ℝ. `AcceleratedVector` is a performance-tuned concrete sibling, not a replacement for that abstraction.

```swift
import Math

let v = AcceleratedVector([1.0, 2.0, 3.0])
// or:
let w = [4.0, 5.0, 6.0].asAcceleratedVector

v + w                       // [5, 7, 9]  — vDSP_vaddD on Apple
v - w                       // [-3, -3, -3]
2.0 * v                     // [2, 4, 6]
v.infinityNorm              // 3.0

// Collection conformance: for-each, subscript, map, filter, reduce all work.
v[1]                        // 2.0
for x in v { … }
v.filter { $0 > 1 }         // [Double] — Array semantics for non-type-preserving ops
v.mapAccelerated { $0 * 2 } // AcceleratedVector — preserves the type for (Double) -> Double
```

**Why a wrapper around `[Double]`?** Swift selects the `VectorState` protocol witness for `+` and `*` at the conformance site. `Array<Element>` conforms when `Element: ℝ` — generic over Element, so the witness uses the scalar `zip(...).map(+)` implementation. There's no way to "specialise" that witness for `Element == Double` without violating the protocol rules (multiple conformances, name-clash with the existing `+`). `AcceleratedVector` sidesteps the problem by being its own concrete type whose witness for `+` IS the vDSP path. Generic solver code dispatches naturally through the witness — no specialisation overloads on RK45 / RK4, no runtime type checks, no `.+` operator.

**Why not generic `AcceleratedVector<T: ℝ>`?** The same dispatch problem. A generic version would have to declare its `VectorState` conformance for any `T: ℝ`, and the witness body couldn't call `vDSP_vaddD` because it wouldn't know `T == Double`. The whole reason for AcceleratedVector existing is that it's *concrete*. For `Float` (which also has vDSP / cblas support), the right shape is a sibling concrete type — `AcceleratedFloatVector` or similar — when a consumer actually needs it. For `Decimal`, `Float80`, `Float16` etc. there's no fast path to add; consumers stay on `Array<T>`.

**When AcceleratedVector doesn't matter**: on non-Apple builds (Linux / WASM) and on Apple builds with `-D SWIFTCALX_NO_ACCELERATE`, `AcceleratedVector`'s `+` / `*` fall back to the same scalar Swift implementation that `[Double]` uses. No win; no loss. The performance edge is specifically vDSP.

**Operators in `MathOperators`**:
- `A ⋅ v` — `Matrix<Double> · AcceleratedVector`, returns `AcceleratedVector`. Bridges `⋅` callers into accelerated-land.
- `α ⋅ v` — scalar `·` vector.
- `u ⋅ v` — vector dot product (`Σ uᵢ · vᵢ`), routes through `cblas_ddot` on Apple.

**FP integration**: `AcceleratedVector` ships `fmap` / `bind` / `kleisli` / `liftA2` / `apply` / `foldLeft` / `foldRight` / `foldMap` / `cartesian` / `seqLeft` / `seqRight` / `zip` plus a direct `Monoid` conformance under concatenation (mirrors `Array`'s direct Monoid). Distinct from elementwise `+` (which lives on `VectorState`) — `combine` joins vectors end-to-end and `identity` is empty.

**Use cases**: state vectors for biokinetic / chemical-kinetics ODE solvers; any place a `[Double]` flows through `RungeKutta4` / `RungeKutta45` / a custom `VectorState` consumer where the per-step `+` and `*` are non-trivial overhead.

---

## Matrices

A matrix is a rectangular table of numbers. Mathematically: an `M × N` matrix represents a linear transformation from an N-dimensional space to an M-dimensional one — you multiply it by a vector of length N and get out a vector of length M.

In SwiftCalx:

```swift
import Math
import MathOperators

let A = Matrix<Double>(rows: 2, columns: 2, storage: [
    1, 2,
    3, 4,
])
```

Storage is **row-major**: `storage[r * columns + c]` is the entry at row `r`, column `c`. This matches NumPy's default and C's array layout.

### Operations

```swift
let B = Matrix<Double>(rows: 2, columns: 2, storage: [5, 6, 7, 8])

let sum     = A + B                   // element-wise addition
let diff    = A - B                   // element-wise subtraction
let scaled  = 2.0 * A                 // scalar multiplication (scalar on left)
let product = A ⋅ B                   // matrix-matrix product (dot operator)
let vec     = A ⋅ [1.0, 2.0]          // matrix-vector product → [Double]
let squared = A.squared(times: 3)     // A^(2^3) = A^8 via repeated squaring
let updated = A.with(row: 0, column: 1, value: 99) // immutable single-element edit

// Mutating counterparts of every operator above:
var acc = A
acc += B          // in-place add
acc -= B          // in-place subtract
acc *= 3.0        // in-place scalar multiply
acc *= B          // in-place matrix multiply
```

The `⋅` operator (the DOT OPERATOR character, U+22C5) is from `MathOperators`. It's overloaded for `Matrix ⋅ Matrix`, `Matrix ⋅ Vector` (i.e. `[Scalar]`), and `Scalar ⋅ Matrix`. Named-function equivalents (`A.applied(to: vector)`, `A * B`) are also available for projects that don't want the operator.

### Iterated action — applying a matrix many times

When you want the trajectory of a vector under repeated application of the same matrix — `[x, M·x, M²·x, …, Mⁿ·x]` — use `actions(on:count:)`:

```swift
let trajectory = M.actions(on: x0, count: 1000)
// trajectory.count == 1001 (initial + n applications)
// trajectory[k] == M^k · x0
```

Why a dedicated method instead of `Mⁿ · x0` via `squared(times:)`? Cost. Repeated matrix multiplication is `O(n · rows³)`. Repeated matrix-vector application is `O(n · rows · cols)` — typically an order of magnitude cheaper, and the only thing that survives to the result is the trajectory anyway.

This is the practical mechanic behind **Birchall's matrix-exponential semigroup**: pre-compute `B = exp(Δt · A)` once with a single matrix exponential, then walk the linear-ODE trajectory with `B.actions(on: y₀, count: n)`. One expensive exp + n cheap mat-vecs, instead of n + 1 independent matrix exponentials. Numerical caveat: iterating `M·x` accumulates floating-point error roughly as `n · ε · κ(M)`, so well-conditioned matrices stay accurate over many iterations; stiff systems may not.

### Matrix.Sum and Matrix.Product — folding semigroup-style

Matrix addition and multiplication are both natural Monoid operations, but their identities (the zero matrix and `Iₙ`) need a runtime shape that Swift's `static var identity: Self` can't carry. So `Matrix` follows FP's `NumericMonoid.Sum` / `NumericMonoid.Product` pattern and ships **newtype Semigroups** instead — fold with `sconcat(_:_:)` (non-empty input, no identity required):

```swift
import CoreFP

let matrices: [Matrix<Double>] = [/* shape-matched */]
let summed = sconcat(Matrix.Sum(matrices[0]), matrices.dropFirst().map(Matrix.Sum.init))
summed.rawValue   // elementwise sum of all matrices

let multiplied = sconcat(Matrix.Product(matrices[0]), matrices.dropFirst().map(Matrix.Product.init))
multiplied.rawValue   // chained matrix product
```

(`Matrix.Product.combine` is the algebraic content of the matrix-exponential semigroup `exp((s+t)·A) = exp(s·A) · exp(t·A)`. For the practical iterated-action form, prefer `actions(on:count:)` above — it avoids the `O(n³)` per-step cost of multiplying matrix powers.)

### Hardware-accelerated mat-vec and mat-mat

`Matrix<Double>` and `Matrix<Float>` route their two hot operations — `apply(to:)` (matrix-vector) and `*` (matrix-matrix) — through Apple's Accelerate framework when available. No API change; the public methods stay identical. Routing is selected at compile time:

| Platform / config | Backend | What runs |
|---|---|---|
| Apple (Mac / iOS / tvOS / watchOS / visionOS) | **Accelerate** | `cblas_dgemv` / `cblas_dgemm`; `vDSP_*` for elementwise `+`, `-`, scalar `*` |
| Linux, WASM, anywhere `Accelerate` is unavailable | **Scalar Swift loops** | The portable implementations in `Matrix+Arithmetic.swift` |
| Apple with `-D SWIFTCALX_NO_ACCELERATE` | **Scalar Swift loops** | For testing / benchmarking the fallback on Apple hardware |

Expected speedups for typical biokinetic / engineering matrix sizes (16×16 to 100×100): **5–10×** on mat-vec, **10–30×** on mat-mat on Apple via Accelerate. The wins grow with matrix size — Accelerate does cache blocking, prefetching, and (on M-series Macs) uses the AMX coprocessor for large enough operands.

Other `Scalar` types (`Decimal`, `Float80`, `Float16`) always use the scalar Swift path — there's no cblas equivalent for them.

**Linux performance**: an OpenBLAS-based bridge package is tracked as a future iteration in `MIGRATION_PLAN.md`. The shape will be a separate `swift-calx-openblas` Swift package consumers add explicitly when they want the Linux fast path — same repo can't ship OpenBLAS support cleanly because SwiftPM lacks a "build this system library only if `pkg-config` succeeds" condition.

### Why "repeated squaring"?

If you need `A^n` for some large `n`, the naive approach `A * A * A * ... * A` (n multiplications) is wasteful. **Repeated squaring** uses the identity `A^(2^k) = ((((A^2)^2)^2)…^2)` — `k` multiplications instead of `2^k`. For `n = 1024`, that's 10 multiplications vs 1024.

The library uses this internally for the Taylor exponential of matrices (see below) and the dosimetry consumer's [Birchall algorithm](https://github.com/luizmb/MultiCompartmentModel) uses it to compute `e^A` via scaling-and-squaring.

**Use cases**: linear algebra, graphics (transformation matrices), Markov chains (state-transition matrices), ODE systems with constant coefficients (matrix exponential), least-squares regression (normal equations).

**Read more**: [Wikipedia — Matrix (mathematics)](https://en.wikipedia.org/wiki/Matrix_(mathematics)); [Wikipedia — Matrix multiplication](https://en.wikipedia.org/wiki/Matrix_multiplication); [Exponentiation by squaring](https://en.wikipedia.org/wiki/Exponentiation_by_squaring).

---

## Numerical derivatives

### What is a derivative?

The derivative of a function `f(x)` measures **how fast `f` changes when `x` changes a little**. It's the slope of the tangent line to `f` at point `x`. Formally:

> `f'(x) = lim[h→0] (f(x + h) − f(x)) / h`

In English: take two points on the curve very close to each other, compute the slope of the line between them, and shrink the gap to zero.

For nice functions like `x²`, we can find the derivative symbolically: `f(x) = x²` → `f'(x) = 2x`. That's calculus.

For functions you only have as code (or as measured data), you can't differentiate symbolically. You can only evaluate `f` at chosen points. **Numerical differentiation** approximates `f'(x)` from a handful of `f(x ± h)` evaluations with cleverly chosen weights, called a **finite-difference stencil**.

Simplest example, the **two-point forward difference**:

> `f'(x) ≈ (f(x + h) − f(x)) / h`

This is just the definition with `h` kept small instead of taken to zero. It's accurate to order `O(h)` — halving `h` halves the error.

Better: the **three-point central difference** uses points on both sides of `x`:

> `f'(x) ≈ (f(x + h) − f(x − h)) / (2h)`

Symmetric about `x`. Accurate to `O(h²)` — halving `h` cuts the error by a factor of 4.

Higher orders use more points (five-point stencils for `O(h⁴)`, seven-point for higher) and clever weighting (Fornberg's algorithm computes the optimal weights for any number of points and any derivative order).

### DerivativeMethod — picking a stencil

`DerivativeMethod<Scalar>` is a **witness value type** — a small struct that holds:

- `order`: which derivative you want (`1` for `f'`, `2` for `f''`, `3` for `f'''`, …)
- `deriving`: a `@Sendable` closure `(Fn<Scalar>) -> Fn<Scalar>` that takes a function and returns its derivative (also a function).

```swift
public struct DerivativeMethod<Scalar: ℝ>: Sendable {
    public let order: Int
    public let deriving: @Sendable (Fn<Scalar>) -> Fn<Scalar>
}
```

You don't construct it by hand; you pick one from a factory. The factories live under namespaces when there's a family of related methods, and as flat factories with author-prefixed names when there's just one method per "thing":

```swift
// Family with multiple variants — surfaces them together in autocomplete:
DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .adaptative)
DerivativeMethod<Double>.CentralStencil.fivePoint(order: 2, step: .adaptative)

// Single-method algorithm — flat name for one-tap discoverability:
DerivativeMethod<Double>.richardsonExtrapolation(coarse: …, fine: …, leadingOrder: 2)
DerivativeMethod<Double>.fornbergCentralStencil(points: 7, order: 3, step: .constant(0.05))
DerivativeMethod<Double>.custom(order: 1) { fn in /* your own deriving logic */ }
```

The naming convention: **algorithm-author names** (Richardson, Fornberg, Birchall, Taylor, Dormand-Prince) give immediate recognition for anyone who's met the algorithm in a numerical methods course or textbook, and serve as a search term for the canonical paper.

### CentralStencil, ForwardStencil, BackwardStencil

These three namespaces hold finite-difference formulas that differ in **which side of `x` they sample**.

**`CentralStencil`** uses symmetric points around `x`: `x − 2h, x − h, x, x + h, x + 2h`. Most accurate per evaluation; needs `f` defined on both sides of `x`. Use it whenever you can.

- `CentralStencil.threePoint(order: 1|2, step:)` — three points centred on `x`. Order 1 (`f'`): `[−1, 0, 1] / (2h)`, accurate to `O(h²)`. Order 2 (`f''`): `[1, −2, 1] / h²`, also `O(h²)`.
- `CentralStencil.fivePoint(order: 1|2|3|4, step:)` — five points. Order 1: `[1, −8, 0, 8, −1] / (12h)`, accurate to `O(h⁴)`. Higher orders supported but with reduced accuracy.

**`ForwardStencil`** uses `x, x + h, x + 2h, …` only. Use it at a **left boundary** of the function's domain (where there's nothing to your left). Lower accuracy than central for the same number of points (only `O(h)` for the two-point version), but no choice if `f(x − h)` doesn't exist.

- `ForwardStencil.twoPoint(order: 1, step:)` — the textbook `(f(x + h) − f(x)) / h`. Accurate to `O(h)`.
- `ForwardStencil.threePoint(order: 1|2, step:)` — `O(h²)` for both orders.

**`BackwardStencil`** is the mirror of `ForwardStencil`: uses `x, x − h, x − 2h`. Use it at a **right boundary**.

If you ask for an unsupported `(stencil, order)` combination (e.g. `threePoint(order: 5)`), the method evaluates to `NaN` rather than crashing. `NaN` propagates naturally through downstream math and respects SwiftCalx's "no fatal errors in numerical code" invariant.

```swift
import Calculus

let f = Fn<Double> { x in sin(x) }   // some function — could be anything

let method = DerivativeMethod<Double>.CentralStencil.fivePoint(
    order: 1,
    step: .adaptative
)
let fPrime = method.deriving(f)
fPrime(.pi)   // ≈ cos(π) ≈ −1, accurate to ~1e-7 with adaptative step
```

**Use cases**: anywhere you have `f` as code but need `f'`. Newton's method for root finding, gradient computations for optimisation, sensitivity analysis, slope fields for ODE visualisation, numerical Jacobians for multidimensional Newton.

**Read more**: [Wikipedia — Finite difference coefficient](https://en.wikipedia.org/wiki/Finite_difference_coefficient); [Press et al., *Numerical Recipes*, §5.7](https://numerical.recipes/).

**Composing methods**: `DerivativeMethod` conforms directly to FP's ``Monoid`` under left-to-right composition. `combine = then(_:)` chains derivers (orders add); `identity` is the no-op method that returns its input unchanged. Same convention FP applies to `String`/`Array`: composition is the only canonical operation, so no `.Composition` wrapper.

```swift
import CoreFP

let stencil = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .adaptative)

// Chain manually:
let secondDerivative = stencil.then(stencil)   // order 2 = 1 + 1

// Or fold a pipeline through mconcat:
let pipeline: DerivativeMethod<Double> = mconcat(Array(repeating: stencil, count: 3))   // order 3
```

Chaining 1st-order stencils to get higher orders compounds truncation error — prefer a direct higher-order method (e.g. `CentralStencil.fivePoint(order: 2, …)`) when one exists. Composition is for cases where no direct method fits, or for combining heterogeneous stages.

### Richardson extrapolation

A trick to **boost a method's accuracy** without writing a higher-order method from scratch. Given a method `M` with leading error `O(h^p)`, Richardson combines two evaluations — one with step `h` and one with step `h/2` — to cancel the leading error term and leave error of higher order.

> `(2^p · M(h/2) − M(h)) / (2^p − 1) = f'(x) + O(h^(p+1))`

```swift
let coarse = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.1))
let fine   = DerivativeMethod<Double>.CentralStencil.threePoint(order: 1, step: .constant(0.05))
let extrap = DerivativeMethod<Double>.richardsonExtrapolation(
    coarse: coarse,
    fine: fine,
    leadingOrder: 2   // 2 for central differences, 1 for one-sided
)
// extrap is a method with effectively O(h⁴) accuracy
```

**Use cases**: pushing accuracy when adding more grid points isn't easy (e.g. when `f` is expensive to evaluate). Romberg integration applies the same idea to quadrature.

**Read more**: Richardson, L.F. (1911). *The approximate arithmetical solution by finite differences of physical problems*. Philosophical Transactions of the Royal Society A 210: 307–357. [Wikipedia — Richardson extrapolation](https://en.wikipedia.org/wiki/Richardson_extrapolation).

### Fornberg's algorithm — custom stencils

Need a 7-point central stencil for the 3rd derivative? Or 9-point for the 4th? Hand-deriving the coefficients (solving a linear system over the Vandermonde matrix) is painful. Fornberg's algorithm computes them **at construction time** by an elegant recurrence.

```swift
let method = DerivativeMethod<Double>.fornbergCentralStencil(
    points: 7,        // must be odd, ≥ 3
    order: 3,         // 1 ≤ order < points
    step: .constant(0.05)
)
// The 7-point central stencil weights for the 3rd derivative are computed
// once when this line runs, and reused at every evaluation of `method.deriving(f)`.
```

Restricted to `Scalar == Double` because the recurrence needs rational arithmetic that's painful to express generically over arbitrary `ℝ` types (without an `Int → Scalar` bridge). The hand-coded `threePoint` / `fivePoint` stencils work for any `ℝ`.

**Use cases**: when you need a specific stencil that isn't in `CentralStencil` / `ForwardStencil` / `BackwardStencil`. Higher-order finite-difference PDE solvers, spectral methods, custom interpolation.

**Read more**: Fornberg, B. (1988). *Generation of finite difference formulas on arbitrarily spaced grids*. Mathematics of Computation 51(184): 699–706. [Wikipedia — Finite difference coefficient](https://en.wikipedia.org/wiki/Finite_difference_coefficient).

### StepCalculator — choosing h

Every numerical derivative needs a step size `h`. Too big: the approximation is rough (the curve isn't really linear over `[x − h, x + h]`). Too small: floating-point cancellation in `f(x + h) − f(x)` destroys precision (subtracting nearly equal numbers loses digits).

The optimal `h` depends on `f` and on `x` — it's roughly `√ε · |x|` where `ε` is machine epsilon, but the constant in front matters. `StepCalculator` is a witness struct holding a `calculate(_ x: Scalar, _ fn: Fn<Scalar>) -> Scalar` closure:

- `.epsilonSquareRoot` — `h = √ε · max(|x|, 1)`. The textbook default for first derivatives.
- `.epsilonCubeRoot` — `h = ε^(1/3) · max(|x|, 1)`. Theoretically optimal for second derivatives.
- `.adaptative` — picks square root or cube root based on the method order.
- `.adaptativeZeroHigh` — same as adaptative but uses a larger step near `x = 0`.
- `.constant(_:)` — fixed `h`, no thinking.
- `.customHforX(_:)` — your own `(x) -> h` function.

For most uses, **`.adaptative`** is the right default. Use `.constant(_:)` only when you have a specific reason (e.g. matching an analytical step from a paper, or in tests where determinism matters).

**Use cases**: tuning the precision/cost tradeoff in `DerivativeMethod` instances.

**Read more**: Press et al., *Numerical Recipes*, §5.7.

### DerivativeFunction — paired function + method

Glues a function `f` and a `DerivativeMethod` together, exposing the slope function via `slopeFunction`, point sampling via `point(at:)`, perpendicular-slope computation, differentiability tests, and chained higher-order differentiation:

```swift
import Calculus

let f = Fn<Double> { x in x * x * x }   // f(x) = x³, so f'(x) = 3x²
let df = DerivativeFunction(
    underlyingFunction: f,
    method: .CentralStencil.fivePoint(order: 1, step: .adaptative)
)

df(x: 2.0)              // ≈ 12 (true value 3·4 = 12)
df.slopeFunction(3.0)   // ≈ 27 (true value 3·9 = 27)

// Differentiate again with a new (higher-order) method — better accuracy:
let ddf = df.differentiate(method: .CentralStencil.fivePoint(order: 2, step: .adaptative))
ddf(x: 2.0)             // ≈ 12 (true value 6x = 12)

// Or chain the original method (accuracy compounds — prefer an explicit
// higher-order method when accuracy matters):
let ddfChained = df.differentiate()
ddfChained(x: 2.0)      // ≈ 12 but with more numerical noise

// Differentiability check:
df.isDifferentiable(at: 0, h: 1e-3)   // true for x³
let absF = Fn<Double>(abs)
let dAbsF = DerivativeFunction(underlyingFunction: absF, method: df.method)
dAbsF.isDifferentiable(at: 0, h: 1e-3) // false — |x| has a corner at 0

// Perpendicular slope — useful for normal-line construction:
let normal = df.perpendicular()   // −1 / df.slopeFunction
```

**Use cases**: any pipeline that needs both a function and its derivative — root finding, optimisation, geometric construction of normals/tangents, differentiability diagnostics.

---

## Taylor series for matrices

The exponential function `e^x` has a famous power-series expansion:

> `e^x = 1 + x + x²/2! + x³/3! + x⁴/4! + …`

This extends to **matrices** by replacing `x` with a square matrix `A`:

> `e^A = I + A + A²/2! + A³/3! + …`

where `I` is the identity matrix.

`e^A` matters because **the solution to a linear ODE system `dy⃗/dt = A·y⃗` is `y(t) = e^(A·t) · y₀`**. If you can compute the matrix exponential, you can solve any constant-coefficient linear ODE *exactly*, in one step, without numerical integration.

`Calculus.Taylor.exponential(of:tolerance:maxIterations:)` computes it by direct power-series summation:

```swift
import Math
import Calculus

let A = Matrix<Double>(rows: 2, columns: 2, storage: [
    -0.1, 0,
    0.1, -0.05
])
let expA = Taylor.exponential(of: A, tolerance: 1e-10)
```

### Caveat: it's accurate only for "small" matrices

If `A` has large entries, the partial sums grow huge before the `n!` denominator catches up, and floating-point cancellation destroys accuracy. The standard fix is **scaling and squaring**: divide `A` by `2^k` large enough that `A / 2^k` has small entries; compute the Taylor series of the scaled matrix safely; then square the result `k` times to recover `e^A = (e^(A/2^k))^(2^k)`.

The scaling-and-squaring assembly lives in the dosimetry consumer ([`MultiCompartmentModel`](https://github.com/luizmb/MultiCompartmentModel), look for `Birchall.swift`) because Birchall 1986 published the specific scaling threshold for compartmental dosimetry models. The generic building blocks (`Taylor.exponential` and `Matrix.squared(times:)`) stay here. If a non-Birchall variant (Padé approximant, Moler & Van Loan algorithm 11) is ever needed in pure linear algebra, it lands in SwiftCalx under its own namespace.

**Use cases**: solving any linear ODE system analytically — coupled spring-mass systems, RC circuits, biokinetic compartmental models, predator-prey systems linearised around equilibrium.

**Read more**: Moler & Van Loan (2003). *Nineteen Dubious Ways to Compute the Exponential of a Matrix, Twenty-Five Years Later*. SIAM Review 45(1): 3–49. [Wikipedia — Matrix exponential](https://en.wikipedia.org/wiki/Matrix_exponential).

---

## Solving differential equations (ODEs)

### What is an ODE?

An **ordinary differential equation** is a recipe like "the rate of change of `y` with respect to `t` is some function of `t` and `y`":

> `dy/dt = f(t, y)`

with an initial condition `y(0) = y₀`. The job of an ODE solver is to find `y(t)` for `t > 0`.

Examples:

- **Radioactive decay**: `dy/dt = −k·y` with rate `k`. Exact solution: `y(t) = y₀·e^(−k·t)`.
- **Newton's cooling**: `dy/dt = −k·(y − y_env)` — temperature `y` approaches ambient `y_env` exponentially.
- **Simple harmonic oscillator** (vector ODE): `dx/dt = v`, `dv/dt = −ω²·x` — a pendulum or a spring. State is `(x, v)`.
- **Lotka-Volterra predators and prey** (vector ODE): two coupled equations for the populations of two species.

Most real ODEs don't have a closed-form solution — you can't write `y(t)` as a formula in terms of `t`. **Numerical solvers** approximate `y(t)` step by step: start at `(t₀, y₀)`, use `f` to estimate the slope, take a small step in `t`, repeat.

SwiftCalx ships two solvers in this family.

### RungeKutta4 — classical fixed-step solver

The textbook 4th-order Runge-Kutta method, published in the 1900s and still the workhorse of "I need to solve this ODE and don't want to think too hard". Per step:

1. `k₁ = f(t, y)` — slope at the start of the interval.
2. `k₂ = f(t + Δt/2, y + Δt/2 · k₁)` — slope at the midpoint, using Euler from `k₁`.
3. `k₃ = f(t + Δt/2, y + Δt/2 · k₂)` — slope at the midpoint again, using `k₂`.
4. `k₄ = f(t + Δt, y + Δt · k₃)` — slope at the end, using `k₃`.

The next `y` is `y + Δt · (k₁ + 2k₂ + 2k₃ + k₄) / 6` — a Simpson's-rule weighted average of the four slope samples. The weighting lives in [`SimpsonWeightedAverage`](#simpsonweightedaverage--the-weighting-underneath) so the algorithm and the weighting are written once each.

**Fourth-order accurate** means the local error per step is `O(Δt⁵)` and the global error after integrating from `t₀` to `t_n` is `O(Δt⁴)`. Halving the step size cuts the error by 16.

Scalar example (1D ODE, `y` is a single number):

```swift
import RungeKutta

// y' = x·√y, y(0) = 1 — exact solution y(x) = (x² + 4)² / 16
let stepFn = RungeKutta4.rk4 { p in p.x * sqrt(p.y) }
let appender = RungeKutta4.calculateNextPoint(Δx: 0.1, stepCalculator: stepFn)
let points = stride(from: 0.1, through: 10, by: 0.1).reduce(
    [BidimensionalPoint(x: 0, y: 1)],
    appender
)
points.last?.y   // ≈ 26.0 (exact: 104² / 16 = 26.0)
```

Vector example (multi-component ODE, `y` is a vector):

```swift
let trajectory = RungeKutta4.trajectory(
    from: [1.0, 0.0],                                  // state at t = 0
    derivative: { _, y in [y[1], -4 * y[0]] },          // harmonic oscillator: ω² = 4
    step: 0.05,
    through: 10
)
// trajectory: [(time: 0, state: [1, 0]), (time: 0.05, state: [...]), …]
```

**When to use it**: smooth ODEs where you know a step size that works (or you don't care about being optimal). Deterministic output cadence is helpful for plotting and snapshotting.

**Read more**: Butcher, *Numerical Methods for Ordinary Differential Equations* (Wiley, 2016), §2.4. Press et al., *Numerical Recipes*, §17.1. [Wikipedia — Runge-Kutta methods](https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_methods).

### RungeKutta45 — Dormand-Prince adaptive solver

The Runge-Kutta method most production code uses today. SciPy's `ode45`, MATLAB's `ode45`, GSL, and most non-stiff ODE solvers default to **Dormand-Prince 5(4)** — a pair of embedded Runge-Kutta formulas that compute, from the same seven slope samples per step:

- A 5th-order accurate estimate `y₅` of `y(t + h)`.
- A 4th-order accurate estimate `y₄` of `y(t + h)`.

The difference `|y₅ − y₄|` is a usable estimate of the local truncation error. The integrator uses this to **adaptively size the step**:

- If error is below `tolerance`: accept the step, and grow `h` for the next step (because the integrator can probably afford a bigger step).
- If error is above `tolerance`: reject the step, shrink `h`, and retry. No advance happens until the step is acceptably accurate.

The growth/shrink factor is `0.9 · (tolerance / error)^(1/5)`, clamped to `[0.1, 5]` so one bad step can't crash the step size or grow it past the next problematic region.

**FSAL** (First-Same-As-Last): `k₇` of an accepted step equals `k₁` of the next step. The integrator caches and reuses it, saving one function evaluation per accepted step.

#### Dense output — querying the trajectory at chosen times

The adaptive integrator picks the times it wants for accuracy; you pick the times you want for output. SwiftCalx bridges them with **dense output**: each accepted segment stores both endpoint slopes, and `trajectory(at:…)` returns the state at any time you ask for via `C¹`-continuous, `O(h⁴)` cubic-Hermite interpolation between segments.

```swift
import RungeKutta

// Harmonic oscillator d²x/dt² = -ω²x, written as the coupled first-order
// system y = [x, x'], dy/dt = [x', -ω²x]. Exact: x(t) = cos(ω t).
let values = RungeKutta45.trajectory(
    at: [0, 1, 2, 5, 10],                              // exactly these times
    from: [1.0, 0.0],                                  // initial [x, x']
    derivative: { _, y in [y[1], -4 * y[0]] },          // ω² = 4
    tolerance: 1e-8
)
// values: [State]  — one entry per requested time, interpolated from the
//                   adaptive trajectory the integrator chose internally.
```

Requesting a time before `startingAt` returns the initial state; requesting one past the integrated range returns the last computed state. Empty input returns `[]`.

The integrator's own adaptive samples are still reachable when you need them — typically for diagnostics or plotting the raw steps the integrator chose:

```swift
let segments = RungeKutta45.denseSegments(
    from: [1.0, 0.0],
    derivative: { _, y in [y[1], -4 * y[0]] },
    through: 10,
    tolerance: 1e-8
)
// segments: [RungeKutta45.Segment]  — startTime, endTime, startState, endState,
//                                     startSlope, endSlope per accepted step.
// Use RungeKutta45.cubicHermite(at:on:) to interpolate inside one segment.
```

**When to use it**: smooth non-stiff ODEs where you don't want to hand-tune a step size. Set a tolerance, hand it the times you care about, let the integrator do the rest. For long integrations across regions of different "speed" (rapidly changing then smoothly settling), the adaptive step is a big win and dense output decouples your output cadence from the integrator's internal one.

**Accuracy note**: cubic Hermite is `O(h⁴)` locally — one order short of the 5th-order integrator. For the smooth linear ODEs typical of biokinetic / chemical-kinetics / control-system applications, this gap is invisible in practice (with `tolerance ≤ 1e-8`, interpolation error stays below `1e-9` even when RK45 takes day-long strides). Dormand-Prince's published 5th-order continuous extension would close the gap entirely; it's planned for a future release if a concrete use case (chaotic dynamics, ultra-fine plotting) demands it.

**Performance note — `AcceleratedVector` opt-in fast state type**: wrapping your `[Double]` in `AcceleratedVector` (`AcceleratedVector([1.0, 2.0])` or `[1.0, 2.0].asAcceleratedVector`) routes every per-stage `+` and scalar `*` through vDSP-backed implementations via the protocol witness. The generic trajectory body is unchanged; the dispatch is automatic because `AcceleratedVector` is its own concrete `VectorState` conformer with optimised operations. Apple-only (vDSP); on Linux / `-D SWIFTCALX_NO_ACCELERATE` the same `AcceleratedVector` falls back to scalar Swift. See [AcceleratedVector](#acceleratedvector) for the type itself.

**Read more**: Dormand, J.R. & Prince, P.J. (1980). *A family of embedded Runge-Kutta formulae*. Journal of Computational and Applied Mathematics 6(1): 19–26. Hairer, Nørsett & Wanner, *Solving Ordinary Differential Equations I: Nonstiff Problems* (Springer, 1993), §II.5 (algorithm) and §II.6 (dense output). [Wikipedia — Dormand-Prince method](https://en.wikipedia.org/wiki/Dormand%E2%80%93Prince_method); [Cubic Hermite spline](https://en.wikipedia.org/wiki/Cubic_Hermite_spline).

### Choosing between RK4 and RK45

Both can deliver state at any output time you ask for (RK4 directly via its fixed grid; RK45 via dense output). The choice is about cost, not output shape.

| Situation | Recommended |
|---|---|
| Step size known analytically (from a paper, a stability analysis) | `RungeKutta4` |
| Predictable cost per output sample matters more than adaptivity | `RungeKutta4` |
| Don't want to think about step size; want the integrator to manage it | `RungeKutta45` |
| Smooth long integration with mixed timescales (some intervals smooth, some rapid) | `RungeKutta45` |
| Linear ODE with constant coefficients (`dy⃗/dt = A·y⃗`) | **Neither — use the matrix exponential** via `Taylor.exponential` or a scaling-and-squaring variant. It's exact. For trajectory walks, [`Matrix.actions(on:count:)`](#iterated-action--applying-a-matrix-many-times) is the cheap form. |
| Stiff ODE (eigenvalues of Jacobian differ by orders of magnitude) | **Neither** — explicit RK needs tiny steps for stability, not accuracy. Use an implicit method (BDF / Rosenbrock / implicit RK5). Not yet shipped; see [Roadmap](#roadmap). |

### SimpsonWeightedAverage — the weighting underneath

The "Simpson's rule" 4-point weighted average `(v₁ + 2·v₂ + 2·v₃ + v₄) / 6` shows up inside both `RungeKutta4.rk4` and its vector overload. It's also Simpson's 1/3 rule for numerical integration — a parabolic approximation to `∫ₐᵇ f(x) dx`.

```swift
SimpsonWeightedAverage.calculate(1.0, 2.0, 3.0, 4.0)
// = (1 + 4 + 6 + 4) / 6 = 15 / 6 = 2.5
```

Extracted to its own namespace so the algorithm and the weighting are decoupled. If a different ODE method (e.g. RK4 variants with different weights) ever needs a different combination rule, it lands here too rather than duplicating the formula.

**Read more**: [Wikipedia — Simpson's rule](https://en.wikipedia.org/wiki/Simpson%27s_rule).

---

## Fibonacci

The famous sequence `0, 1, 1, 2, 3, 5, 8, 13, 21, 34, …` where each term is the sum of the previous two. Shows up in surprising places — phyllotaxis (the arrangement of leaves on a stem), Pascal's triangle diagonals, financial market analysis, computer-science algorithm analysis.

SwiftCalx ships **three** Fibonacci implementations, exposed as a `Sequence` you can iterate:

```swift
import Calculus

let fib = Fibonacci(method: .precise)
let first10 = Array(fib.prefix(10))
// [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
```

- **`.precise`** — iterative `Double`. Exact up to about `F(78)` where `Double`'s mantissa runs out. After that, accumulating rounding errors start to bite. Use when you need exact values for small indices.
- **`.balanced`** — iterative with golden-ratio recurrence. Slightly different rounding behaviour than `.precise`. Faster constant factor for large indices.
- **`.quick`** — Binet's closed-form formula using `cos(nπ)` to handle the alternating-sign term. Instant evaluation at any index but **drifts hard** above `n ≈ 60` because the cosine term loses precision. Use only as a curiosity or for `n < 50`.

`Fibonacci.preciseMethod`, `Fibonacci.balancedMethod`, `Fibonacci.quickMethod` are also available as standalone `Fn<Double>` values if you want to evaluate them outside the iterator.

**Read more**: [Wikipedia — Fibonacci sequence](https://en.wikipedia.org/wiki/Fibonacci_sequence); [Binet's formula](https://en.wikipedia.org/wiki/Fibonacci_sequence#Binet's_formula).

---

## Operators

All operators are in the `MathOperators` module, which most products pull in by default. The convention is **named function first, operator as ergonomic alias second** — there's always a long-form way to spell anything operators do, so you can opt out of custom operators (use `MathNoOperators` / `CalculusNoOperators`) if your project prefers strict standardness.

| Operator | Type | Meaning | Named equivalent |
|---|---|---|---|
| `⋅` | infix, `Matrix * Matrix`, `Matrix * Vector`, `Scalar * Matrix` | Matrix product, matrix-vector product, scalar-matrix product. The character is U+22C5 DOT OPERATOR (not period). | `A.applied(to: vector)`, `A * B`, `scalar * A` |
| `≅` | infix `(Scalar, Range<Scalar>) -> Bool` | Approximate equality — `value ≅ (a..<b)` checks if `value` lies inside `[a, b)`. Useful for "did the algorithm converge close enough to the expected value?". | `value.within(range)` |
| `±` | infix `(Scalar, Scalar) -> Range<Scalar>` | `value ± delta` constructs the symmetric range `[value − delta, value + delta]`. From FP: `5.0 ± 0.1 == 4.9..<5.1`. | `value.symmetricRange(delta)` |
| `+/-` | infix `(Scalar, Scalar) -> Range<Scalar>` | ASCII alias for `±` (for keyboards without easy `±`). | Same as `±`. |
| `√` | prefix `(Scalar) -> Scalar` | Square root. `√4.0 == 2.0`. | `value.squareRoot()` |
| `∛` | prefix `(Scalar) -> Scalar` | Cube root. `∛8.0 == 2.0`. | `value.cubeRoot()` |
| `^^` | infix `(Scalar, Scalar) -> Scalar` | Exponentiation. `2.0 ^^ 3.0 == 8.0`. Note: not `^` (which is bitwise XOR in Swift) and not `**` (Python). | `base.raisedToThePower(of: exponent)` |

Combined with FP's operators (`<£>`, `>=>`, `<*>`, etc.) from `CoreFPOperators`, you get a rich expressive vocabulary. Each operator's precedence is documented in the source.

---

## Logarithms

`Log` namespace provides arbitrary-base logarithms in a small uniform API:

```swift
import Math

Log.base10(100.0)        // 2.0
Log.base2(8.0)           // 3.0
Log.naturalLog(.e)       // 1.0
Log.logC(base: 7.0, of: 49.0)  // 2.0 — generic base
```

`logC(base:of:)` is the general form (`base` and `of` can be any `Double`). The named base-2 / base-10 / natural variants are conveniences. For `Decimal` and other non-`Double` `ℝ` types, the bridge happens internally; precision matches Swift's stdlib `log`/`log10`/`log2`.

**Read more**: [Wikipedia — Logarithm](https://en.wikipedia.org/wiki/Logarithm).

---

## Numeric utilities

`Math.Numeric+Extensions` extends the stdlib numeric protocols with a few utilities common in graphics, signal processing, and curve work:

- `T.linearInterpolation(from:to:t:)` — linearly interpolate from `from` to `to` at parameter `t ∈ [0, 1]`. `linearInterpolation(from: 0, to: 10, t: 0.3)` returns `3.0`. Also known as `lerp`.
- `T.linearProgress(of:from:to:)` — inverse: given a value, find its `t` along the `from → to` line. `linearProgress(of: 3.0, from: 0, to: 10)` returns `0.3`. Useful for "where are we on this scale?".
- `T.interpolateProgress(of:from:to:newRange:)` — combination: given a value in `[from, to]`, map it to a value in `newRange`. Useful for remapping ranges (e.g. mouse coordinate to a slider value).
- `T.logistic(x:k:x0:L:)` — the logistic / sigmoid function, parameterised by steepness `k`, midpoint `x0`, and maximum `L`. Defaults to the standard sigmoid `1 / (1 + e^(−x))`. Useful in neural networks, biology (population growth with carrying capacity), economics (technology adoption curves).

**Read more**: [Linear interpolation](https://en.wikipedia.org/wiki/Linear_interpolation); [Logistic function](https://en.wikipedia.org/wiki/Logistic_function).

---

## Mathematical symbols

`Symbols` is a tiny namespace exposing string constants for the mathematical glyphs the library uses internally — useful when constructing labels, error messages, or plot titles programmatically:

```swift
Symbols.ℝ     // "ℝ"
Symbols.Δ     // "Δ"
Symbols.𝓃    // "𝓃"
```

Not central to most uses; convenience for code that wants to render the same glyphs.

---

## Concurrency: Sendable-first

SwiftCalx follows the same Sendable-first discipline as the underlying `luizmb/FP`. The summary:

- **All protocols** (`ℝ`, `VectorState`, `NormedVectorState`) refine `Sendable`. Any conformer must itself be Sendable. Stdlib numeric types all are; custom conformers should be.
- **All value types** (`Matrix`, `BidimensionalPoint`, `TridimensionalPoint`, `Fibonacci`, `DerivativeFunction`, `DerivativeMethod`, `StepCalculator`, the `Step` struct returned by `RungeKutta45.step`) carry `Sendable` conformance, conditional on their generic parameters being Sendable.
- **All closures stored inside types** (`DerivativeMethod.deriving`, `StepCalculator.calculate`) are `@Sendable`. So are closure parameters of solver methods (`derivative` in `RungeKutta4.trajectory` / `RungeKutta45.trajectory`).

What this means in practice: you can freely use SwiftCalx values across `Task`s, `Actor`s, and `Sendable`-required positions. The deeper FP principle is that composition closures shouldn't capture *anything* (effects nor co-effects) — see the [FP README's Sendable section](https://github.com/luizmb/FP#concurrency-sendable-first) for the full discussion.

---

## Platform support

| Platform | Minimum |
|---|---|
| macOS | 10.15 |
| iOS | 13.0 |
| tvOS | 13.0 |
| watchOS | 6.0 |

Linux builds (no Combine dependency in this library; FP's Combine-touching surface is gated to Apple platforms via `#if canImport(Combine)`).

Swift 5.10 toolchain or later. Swift 6 strict concurrency mode is supported (the library is Sendable-clean throughout).

---

## Roadmap

See [`MIGRATION_PLAN.md`](MIGRATION_PLAN.md) for the full snapshot. Headline pending items:

- **Split into separate repos** (eventually) — `Math`, `MathOperators`, `Calculus`, `RungeKutta`, `SwiftCalx` (umbrella) as independent packages, so consumers pull only what they need.
- **Dormand-Prince 5th-order continuous extension** — match the integrator's accuracy floor on `RungeKutta45` dense output (currently cubic Hermite, `O(h⁴)`). Defer until a use case needs the extra order; for biokinetic and most engineering ODEs the existing interpolant is comfortable.
- **More ODE solvers** when needed — Adams-Bashforth-Moulton (predictor-corrector), BDF (for stiff systems), implicit RK5 (Radau IIA), Rosenbrock.
- **Quadrature** — Simpson, Gauss-Legendre, Romberg, adaptive Gauss-Kronrod.
- **Root finding** — Newton (via existing `DerivativeFunction`), bisection, secant, Brent, multidimensional Newton.
- **Optimisation** — gradient descent, Newton-for-optimisation, BFGS / L-BFGS, conjugate gradient.
- **Linear algebra extensions** — LU / QR / Cholesky, eigenvalues, SVD, sparse matrices.
- **Special functions** — gamma, beta, erf, Bessel.
- **FFT, interpolation, polynomial operations, random sampling** — see the full Future iterations section in `MIGRATION_PLAN.md`.

We don't add things speculatively. Each addition needs a concrete consumer use case or a clear gap that makes the library feel incomplete to its target audience.

---

## References

The canonical references for the algorithms shipped here:

**Runge-Kutta methods**:
- Butcher, J.C. (2016). *Numerical Methods for Ordinary Differential Equations* (Wiley, 3rd ed.).
- Dormand, J.R. & Prince, P.J. (1980). *A family of embedded Runge-Kutta formulae*. JCAM 6(1): 19–26.
- Hairer, Nørsett & Wanner (1993). *Solving Ordinary Differential Equations I: Nonstiff Problems* (Springer).
- Press et al., *Numerical Recipes*, §17.1.
- [Wikipedia — Runge-Kutta methods](https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_methods).

**Numerical differentiation**:
- Fornberg, B. (1988). *Generation of finite difference formulas on arbitrarily spaced grids*. Math. Comp. 51(184): 699–706.
- Richardson, L.F. (1911). *The approximate arithmetical solution by finite differences of physical problems*. Phil. Trans. Roy. Soc. A 210: 307–357.
- Press et al., *Numerical Recipes*, §5.7.
- [Wikipedia — Finite difference coefficient](https://en.wikipedia.org/wiki/Finite_difference_coefficient).

**Matrix exponentials**:
- Moler, C. & Van Loan, C. (2003). *Nineteen Dubious Ways to Compute the Exponential of a Matrix, Twenty-Five Years Later*. SIAM Review 45(1): 3–49.
- Birchall, A. (1986). *A microcomputer algorithm for solving compartmental models involving radionuclide transformations*. Health Physics 50(3): 389–397. (For the dosimetry scaling-and-squaring assembly that lives in the MCM consumer.)
- [Wikipedia — Matrix exponential](https://en.wikipedia.org/wiki/Matrix_exponential).

**Simpson's rule**:
- Burden & Faires, *Numerical Analysis* (Cengage, any edition), §4.4.
- [Wikipedia — Simpson's rule](https://en.wikipedia.org/wiki/Simpson%27s_rule).

**Foundations**:
- [Wikipedia — Real number](https://en.wikipedia.org/wiki/Real_number); [Vector space](https://en.wikipedia.org/wiki/Vector_space); [Norm (mathematics)](https://en.wikipedia.org/wiki/Norm_(mathematics)); [Matrix (mathematics)](https://en.wikipedia.org/wiki/Matrix_(mathematics)); [Matrix multiplication](https://en.wikipedia.org/wiki/Matrix_multiplication); [Exponentiation by squaring](https://en.wikipedia.org/wiki/Exponentiation_by_squaring).

For learning numerical methods from scratch, the textbooks above (Butcher, Hairer, Press et al., Burden & Faires) are excellent. *Numerical Recipes* is freely readable online at [numerical.recipes](https://numerical.recipes/) and is the practical reference for almost every algorithm in this library and beyond.

---

## License

MIT.
