# What's left — SwiftCalx + neighbours

Snapshot: 2026-10-15 (completed items up to SwiftCalx 0.7.0). The original "migration plan" (strip RungeKutta down to math + calculus + RK, point at FP for the plumbing) is complete. This file now tracks the remaining work — package split / consumer coordination — and the deferred design notes.

## ✅ Completed

- **Phase A — FP-duplicate purge (2026-05-19)**. Deleted five modules whose responsibilities now live in `FP`:
  `Monoid`, `Morphisms`, `FoundationCategoryTheory`, `FoundationCategoryTheoryOperators`, `CompositionOperators`.
  Also deleted the small helpers that had already been ported into FP:
  `Comparable.clamped`/`within`, `Array.cartesian`, `Strideable.plusMinus`, `≅` (approximate equality).
  `Math` now depends on `CoreFP`; `MathOperators` on `CoreFPOperators`.
- **Phase B — RK4 correctness + Vector RK (2026-05-18)**. Fixed the RK4 double-add bug (`rk4` now returns pure Δy; `calculateNextPoint` does the single `lastPoint.y + Δy`). Added the `VectorState` protocol + vector-state `rk4` overload. Replaced the stub `RungeKuttaTests` with real scalar + vector + trajectory test files.
- **Math + algorithm namespaces (2026-05-19)**. Added `Math.Matrix<T: ℝ>` (`+`, `*`, scalar `*`, `apply(to:)`, `with(row:column:value:)`, `squared(times:)`); the `⋅` operator wraps `*` / `apply(to:)`. Extracted `Calculus.SimpsonWeightedAverage` (used by both scalar and vector RK4) and `Calculus.Taylor` (matrix-exponential building block). Added `RungeKutta4.trajectory(from:derivative:step:through:)` for one-shot integration.
- **`DerivativeFunction` bug-fixes (2026-05-19)**. `CentralStencil.fivePoint` lost its bogus `fifthPoint` truncation term (`fn(5)` was evaluating the function at literal `5`, not a 4th derivative). `isDifferentiable(at:h:)` rewritten with `√h` tolerance (corners and vertical tangents now detected). `invert()` renamed to `perpendicularSlope()` (the old name implied function inversion; it actually returns `−1 / self(x)`).
- **CalculusPlayground deleted (2026-05-19)**. Referenced an API removed years ago and hadn't compiled since.
- **Sendable cascade (2026-05-21, [PR #1](https://github.com/luizmb/RungeKutta/pull/1))**. Bumped FP to 1.8.1. `protocol ℝ` and `protocol VectorState` refine `Sendable`. `BidimensionalPoint`, `TridimensionalPoint`, `Fibonacci`, `Fibonacci.Method`, `DerivativeFunction` gain conditional `Sendable` conformance. `DerivativeMethod` already stored its `deriving` closure as `@Sendable`.
- **Author-named factory rename (2026-05-21, [PR #3](https://github.com/luizmb/RungeKutta/pull/3))**. `centralStencilCustom` → `fornbergCentralStencil`. Removed the hollow `Richardson` enum placeholder; `richardsonExtrapolation` stays flat alongside `custom` and `fornbergCentralStencil`. Codified the convention: namespace when a family has multiple members; flat author-prefixed name otherwise.
- **RungeKutta45 + NormedVectorState (2026-05-21, [PR #4](https://github.com/luizmb/RungeKutta/pull/4))**. Dormand–Prince 5(4) embedded pair with FSAL and PI step-size control. `NormedVectorState: VectorState` adds an `infinityNorm` requirement (needed by adaptive solvers); conformances for `[Element: ℝ]` and the scalar `ℝ` types.
- **Package rename to `SwiftCalx` (2026-05-21)**. `RungeKutta` / `SwiftMath` umbrella names no longer described the breadth (the package now hosts `Math.Matrix`, `Calculus.Taylor`, `Calculus.SimpsonWeightedAverage`, `Calculus.DerivativeMethod`, `RungeKutta4`, `RungeKutta45`, …). New name from Latin *calx* (small stone for reckoning, root of *calculate*) — short, distinctive, not over-committed to "calculus". Library / target / module names (`Math`, `MathOperators`, `Calculus`, `RungeKutta`, `RealNumber`) stay unchanged so consumers' `import Math` etc. don't break.
- **Algebraic structure bundle (2026-05-21)**. Follows FP's existing conventions: types with a single canonical monoid conform directly (the way FP conforms `String` and `Array` to `Monoid` under concatenation); types with multiple valid monoids get newtype wrappers (the way FP wraps numbers in `NumericMonoid<T>.{Sum, Product, Min, Max}`).
  - **Direct `Monoid` conformance** — `BidimensionalPoint<T>` and `TridimensionalPoint<T>` (additive: combine is `+`, identity is the origin), and `DerivativeMethod<Scalar>` (composition: combine is `then(_:)`, identity is the no-op deriver).
  - **Newtype `Semigroup` wrappers** — `Matrix<Scalar>.Sum` and `Matrix<Scalar>.Product` (naming matches FP's `NumericMonoid.Sum` / `NumericMonoid.Product`). Both natural operations exist, so the wrapper disambiguates. `Semigroup` rather than `Monoid` because the identities (zero matrix / `Iₙ`) need a runtime shape that a `static var Self` can't carry. Folds with `sconcat(_:_:)` (non-empty input) instead of `mconcat(_:)`.
  - `DerivativeMethod.identity` (static var) and `then(_:)` (instance method) are surfaced directly on the type — same primitives the Monoid conformance uses, useful when monoidal folding isn't needed.
  - `Matrix.actions(on:count:)` — iterated semigroup action `[x, M·x, M²·x, …, Mⁿ·x]`. The practical mechanic behind Birchall's matrix-exponential semigroup: one expensive `exp(Δt·A)` + n cheap mat-vecs.
  - `BidimensionalPoint` and `TridimensionalPoint` gain full vector-space arithmetic (`+`, `-`, scalar `*`, `.zero`, `Equatable`, `VectorState` conformance).
- **First SwiftCalx release `v0.1.0` (2026-05-21)**. Tagged via the new `create-rc` / `promote-rc` automation. DocC site live at https://luizmb.github.io/SwiftCalx/.
- **RK45 dense output (2026-05-21)**. `RungeKutta45.trajectory(...)` replaced with the time-list overload `trajectory(at: [Double], ...) -> [State]`. Internally stores both endpoint slopes per accepted segment and interpolates with cubic Hermite (`O(h⁴)`, `C¹`-continuous). The adaptive integrator's raw time grid is still exposed via `RungeKutta45.denseSegments(...) -> [Segment]` for diagnostic use. Breaking change to the trajectory API — landed for SwiftCalx 0.2.0. Closes the consumer's RK45 problem: consumers no longer need to cap `maxStep` to keep linear resampling accurate.
- **Accelerate-backed Matrix ops (2026-05-21)**. `Matrix<Double>` and `Matrix<Float>` mat-vec and mat-mat get routed through Apple Accelerate's hand-tuned kernels — `cblas_dgemv` / `cblas_dgemm` for the matrix ops, plus `vDSP_*` for element-wise `+`, `-`, scalar `*`. Scalar Swift loops in `Matrix+Arithmetic.swift` remain the fallback on Linux / WASM / `-D SWIFTCALX_NO_ACCELERATE`. Three CI cells exercise every path: macOS Accelerate, macOS scalar (via the flag), Linux scalar. No public API change — the routing is `#if`-gated inside specialized extensions, so consumers see the same `Matrix` type with the same operations. Public API and consumer behavior unchanged; just much faster on Apple (estimated 5–10× on mat-vec / mat-mat for typical biokinetic sizes).
- **`AcceleratedVector` opt-in fast state type (2026-05-21)**. Replaces the earlier `[Double]`-specialised trajectory overloads with a cleaner generalisation: a new `AcceleratedVector` struct (concrete `[Double]`-backed) that conforms to ``VectorState`` and ``NormedVectorState`` with vDSP-backed `+`, `-`, scalar `*`, and `infinityNorm` on Apple (scalar Swift fallback elsewhere). Because the conformance is on a concrete type, the protocol witness for `+` / `*` IS the optimised path — generic solver code (RK45, RK4, Birchall's iterated action, anything else over VectorState) automatically picks up vDSP whenever the state is `AcceleratedVector`. No specialisation overloads anywhere in the solvers, no runtime type checks, no `.+` operator gymnastics. Consumers opt in at the entry point: `AcceleratedVector([1.0, 2.0])` or `[1.0, 2.0].asAcceleratedVector` (zero-copy wrapping). `Matrix.apply(to: AcceleratedVector) -> AcceleratedVector` bridges so derivative functions stay in accelerated-land. The earlier `RungeKutta45+DoubleStep.swift` / trajectory overloads are removed.
  - **Name choice**: explicitly *not* `Vector`. The mathematically faithful "vector over `T: ℝ`" abstraction is already `Array<T>: VectorState`; naming the concrete `[Double]`-only fast path `AcceleratedVector` signals that it's a *performance lever* tied to specific hardware (vDSP / cblas on Apple), not the abstraction. A sibling `AcceleratedFloatVector` would land if a Float-precision consumer ever appears. Other scalars (`Decimal`, `Float80`, `Float16`) have no fast path to add and stay on `Array<T>`.
  - **Array-shaped APIs and FP integration lifted to AcceleratedVector**: `RandomAccessCollection` (subscript, count, map / filter / reduce), `Equatable` / `Hashable` / `CustomStringConvertible`, `mapAccelerated` (type-preserving map). FP-style mirrors of `CoreFP/Array+{Functor,Monad,Applicative,Foldable,Cartesian}` — `fmap`, `bind`, `kleisli`, `liftA2`, `apply`, `seqLeft`, `seqRight`, `zip`, `foldLeft`, `foldRight`, `foldMap`, `cartesian`. Direct `Monoid` conformance under concatenation (mirroring `Array`'s direct conformance) lives in the main `AcceleratedVector.swift` file alongside the struct. `⋅` operators in `MathOperators` (`Matrix ⋅ AcceleratedVector`, `Scalar ⋅ AcceleratedVector`, `AcceleratedVector ⋅ AcceleratedVector` dot product via `cblas_ddot` on Apple). Monad transformers (`VectorTOptional` etc.) skipped intentionally: they only make sense over a parameterised element type, and `AcceleratedVector` is concretely `[Double]`.
- **Portability (0.3–0.5)**. Linux CI on the official `swift:6.3` container, Windows and Android CI cells. `exp()` instead of `pow(M_E, ·)` for Windows; `Float` / `Float16` `eⁿ` through a `Double` round-trip for Android. Apache license, SwiftFormat, DocC site.
- **FP 3.0 and performance (0.7.0, 2026-10)**. FP bumped to 3.0.0. Generic `ℝ` code is `@inlinable` buffer loops (no per-element allocation once specialised); generic callers reach BLAS for `Double` / `Float` (`Scalar.self == Double.self` checks, `withMemoryRebound`). In-place `+=` / `-=` / `*=` on `Matrix` and `AcceleratedVector`, `Matrix.multiply(_:_:into:)` for ping-pong buffers (`squared(times:)`, `Taylor.exponential`), `VectorState.add(_:scaledBy:)` so every RK stage is built in place. RK4 gains `calculateNextPointMut` / `calculateNextStateMut` for linear `reduce(into:)` folds. Optics: `Matrix.each` / `diagonal` / `row` / `column` / `entry`, `AcceleratedVector.each` / `ix`. `consuming` only where a copy happens anyway (`Matrix.with`, `AcceleratedVector.combine`, the pure RK4 helpers); on binary operators it measured slower for shared operands. Fixed a vDSP overread on mismatched lengths. Birchall `e^A` (16×16) went from 13 ms to 20 µs. Numbers in the README performance table; `BenchmarkSuite/` measures them.
- **Consumer rename**. `MultiCompartmentModel` is now [`biokinetics-dosimetry`](https://github.com/luizmb/biokinetics-dosimetry) (`BiokineticsDosimetry`), already on SwiftCalx with RK45 dense output and Birchall composition.

## Current layout

```
Math/
  Matrix<Scalar: ℝ>            // row-major matrix + +, *, scalar *, apply(to:), with, squared;
                               // in-place +=, -=, *=, multiply(_:_:into:); BLAS / vDSP on Apple
  Matrix optics                // each, diagonal, row, column (Traversal), entry (AffineTraversal)
  AcceleratedVector            // concrete [Double] state; vDSP on Apple; FP surface + each / ix optics
  VectorState                  // vector-space protocol (+, scalar *, add(_:scaledBy:)); [T: ℝ] and concrete ℝs
  NormedVectorState            // VectorState + infinityNorm; required by adaptive solvers
  BidimensionalPoint, TridimensionalPoint, slope
  Log, Numeric+, Symbols

MathOperators/
  Matrix+Operators             // ⋅ (DOT OPERATOR) for matrix-matrix, scalar-matrix, matrix-vector
  AcceleratedVector+Operators  // ⋅ for matrix-vector, scalar-vector, dot product
  √, ∛, ^^                     // (≅, ±, +/- come from FP's CoreFPOperators)

Calculus/
  SimpsonWeightedAverage       // (v1 + 2v2 + 2v3 + v4) / 6 — used by RK4
  Taylor                       // matrix Taylor series of exp (generic building block)
  Derivative, DerivativeMethod // witness pattern; CentralStencil / ForwardStencil /
                               // BackwardStencil / Compose namespaces + flat
                               // richardsonExtrapolation / fornbergCentralStencil / custom
  Fibonacci, Fn

RungeKutta/
  RungeKutta4                  // fixed-step; scalar + vector overloads; SimpsonWeightedAverage core;
                               // calculateNext…Mut for linear reduce(into:) folds
  RungeKutta4.trajectory(…)    // one-shot integrator returning [(time, state)]
  RungeKutta45                 // Dormand–Prince 5(4) embedded pair, FSAL
  RungeKutta45.trajectory(at:…) // adaptive driver with PI step-size control, cubic-Hermite dense output

SwiftCalx/
  @_exported.swift             // umbrella product re-exporting Math, MathOperators,
                               // Calculus, RealNumber, RungeKutta
```

Birchall's scaling-and-squaring matrix-exponential lives in the dosimetry consumer (`biokinetics-dosimetry/Sources/Solver/Birchall.swift`) because Birchall 1986 published it specifically for compartmental dosimetry models. The generic building blocks it composes — `Math.Matrix`, `Matrix.squared(times:)`, `Calculus.Taylor.exponential` — stay here. If a non-Birchall scaling-and-squaring variant (Padé, Moler & Van Loan algorithm 11, etc.) is ever needed in pure numerical linear algebra, it lands here under its own namespace.

Conventions:
- **Algorithm-author names where possible.** `Birchall`, `Taylor`, `SimpsonWeightedAverage`, `Richardson`, `Fornberg`, `Fibonacci`, `RungeKutta`, `DormandPrince` (referenced inside `RungeKutta45`) — historical names give consumers immediate recognition and a search term for the literature.
- **Namespace when a family has multiple members; flat name otherwise.** `CentralStencil.threePoint` / `CentralStencil.fivePoint` deserves the nesting because both surface together when typing `CentralStencil.`. A single-method "namespace" hurts more than it helps — it costs an autocomplete tap without grouping anything. So `richardsonExtrapolation(coarse:fine:leadingOrder:)` and `fornbergCentralStencil(points:order:step:)` stay flat alongside `custom(order:deriving:)` rather than living inside hollow `Richardson` / `Fornberg` enums.
- Docs are written for non-mathematicians: explain the concept, link to the canonical text (Butcher, Moler–Van Loan, Birchall 1986, Dormand–Prince 1980, Fornberg 1988, Strang, Wikipedia), walk through the algorithm.
- Custom mathematical symbols are welcome (`⋅`, `√`, `^^` already ship). The convention is *named function first, operator as ergonomic alias second*.

---

## ⏳ Pending

### Dormand-Prince 5th-order continuous extension (future RK45 upgrade)
The current dense output uses cubic-Hermite interpolation between accepted RK45 samples (`O(h⁴)` accuracy, one order short of the 5th-order integrator). Dormand-Prince's published 5th-order continuous extension uses all 7 stage slopes — matches the integrator's accuracy floor. ~50 lines of additional Butcher-tableau-style coefficients. Defer until a use case needs the extra order.

### OpenBLAS bridge package for Linux
Linux consumers of SwiftCalx currently fall through to the scalar Swift loops for `Matrix.apply` / `Matrix * Matrix` / etc. — Accelerate is Apple-only, and we don't ship an OpenBLAS path. The clean shape is a separate `swift-calx-openblas` package (its own repo / its own root `Package.swift`) that provides a `COpenBLAS` system-library target. SwiftCalx's `Matrix+BLAS.swift` would gain an `#elseif canImport(COpenBLAS)` branch. Linux consumers add both packages; Apple consumers add only SwiftCalx (Accelerate wins on `canImport`). The reason it's not in the same repo: SwiftPM has no "build this system-library target only if pkg-config succeeds" condition, so a same-repo conditional target makes Linux-without-OpenBLAS builds fail. Worth ~½ day of work once a Linux server consumer materialises.

### Break the package down
Consider splitting into separate **repositories** along module lines:
- `Math` — Matrix, VectorState, NormedVectorState, BidimensionalPoint, TridimensionalPoint
- `MathOperators` — `⋅`, `≅`, `±`, etc.
- `Calculus` — Taylor, SimpsonWeightedAverage, Derivative, DerivativeMethod, Fibonacci, Fn
- `RungeKutta` — RungeKutta4, RungeKutta45, trajectories
- `SwiftCalx` (umbrella) — re-exports everything for one-line imports

Lets consumers pull only what they need (the dosimetry package currently drags the whole umbrella in for Matrix + Taylor + RK4) and lets future FP-duplicate purges happen one package at a time. Trade-off: more `Package.swift` files to maintain; coordinated versioning becomes harder. **Needs user-side work** — creating new GitHub repos, migrating history, redirecting URLs.

### Open design choices (not bugs)

- **State shape for biokinetics / multi-compartment.** When wiring RK4 / RK45 into a multi-compartment model, per-compartment integration with externally-coupled inputs gives the wrong answer — coupled linear ODEs `dy⃗/dt = A·y⃗ + u⃗(t)` need all compartments advanced together at every substep. The generic-state shape (`VectorState` / `NormedVectorState`) we shipped is the right answer; a fixed-width SIMD variant is faster but locks the compartment count at compile time. Defer SIMD until profiling demands it. Because ICRP biokinetic systems are linear with constant rate constants, the **analytic** option `y(t) = exp(A·t) · y₀` is also available (shipped via `Birchall` + `Math.Matrix.squared(times:)`); useful as a ground-truth oracle for the RK solvers and a faster path when intermediate trajectories aren't needed.

### Known-and-documented limitations (not TODOs)

- **Fibonacci `.quick`** (the Binet-via-`cos` form) drifts hard once `n > ~60`; `testCompareFiboAlgorithmPrecision` already accepts `accuracyQuick = 1e7` past index 90. Documented as a curiosity; for arbitrary precision, prefer `Decimal` or genuine bignum.

---

## 🔭 Future iterations

Things to keep in mind for future additions to SwiftCalx. None of these are required by any current consumer — they're potential next moves when the need arises.

### ODE solvers

- **Adams-Bashforth-Moulton** (predictor-corrector) — linear multistep method, reuses past derivatives instead of recomputing them. Fixed-step variant ~200 LoC + tests; variable-step adds ~100 more. Good for long-time smooth integrations where step cost matters; not for stiff systems. Bootstrap with RK4 for the first few steps.
- **Implicit RK5 (Radau IIA)** — A-stable, L-stable, B-stable 5th-order implicit Runge-Kutta. Needs a linear solve per step (LU factorisation of `(I − h·A)` for linear ODEs; Newton iteration for non-linear). ~400 LoC + tests. The right tool for genuinely stiff non-linear systems.
- **BDF (Backward Differentiation Formula)** orders 1–6 — the standard for stiff ODEs (variable-order, variable-step). What SciPy's `LSODA` switches to when it detects stiffness. ~500 LoC + tests.
- **Rosenbrock methods** — semi-implicit (no inner Newton iteration; just one linear solve per stage). Cheaper than fully-implicit on moderately stiff problems. ~300 LoC + tests.
- **Dense output / interpolation** for `RungeKutta45` — allow the adaptive integrator to evaluate `y(t)` at arbitrary `t` between accepted steps using a 5th-order interpolant. Useful for fixed-cadence output without re-running the integrator at chosen times.
- **Other explicit RK variants** — Cash-Karp 5(4), Verner's 6(5) / 8(7) — different Butcher tableaux for accuracy/cost tradeoffs.
- **Implicit Euler (BDF1)** — simple first-order implicit method; useful as a baseline / teaching example for the implicit family.

### Quadrature (definite integrals)

- **Simpson's rule** for `∫ₐᵇ f(x) dx` — adaptive Simpson with error estimation.
- **Gauss–Legendre quadrature** — orthogonal-polynomial weights; very high accuracy for smooth integrands.
- **Romberg integration** — Richardson extrapolation applied to trapezoidal rule.
- **Adaptive Gauss-Kronrod** — the de facto standard adaptive quadrature (`qag` in QUADPACK).
- **Multidimensional quadrature** — tensor product of 1D rules; Monte Carlo and quasi-Monte Carlo for high dimensions.

### Root finding

- **Newton's method** — uses the existing `DerivativeFunction` for the slope; natural fit.
- **Bisection** — guaranteed convergence for sign-changing brackets; slow but bulletproof.
- **Secant method** — Newton without the explicit derivative.
- **Brent's method** — combines bisection / secant / inverse quadratic interpolation; the practical default.
- **Multidimensional Newton** — needs the Jacobian (from `DerivativeMethod` extended to vector-valued functions, or finite-difference approximation).

### Optimisation

- **Gradient descent** — fixed step, momentum, Adam, AdaGrad variants.
- **Newton's method for optimisation** — uses Hessian (second-derivative matrix).
- **Conjugate gradient** — for large sparse systems.
- **BFGS / L-BFGS** — quasi-Newton; approximates the Hessian without storing it.
- **Nelder-Mead** — derivative-free; useful when gradient is unavailable.

### Linear algebra

- **LU decomposition** with partial pivoting — `A x = b` solvers; basis for many implicit-solver inner loops.
- **QR decomposition** — least squares, eigenvalue iterations.
- **Cholesky** — symmetric positive-definite systems; twice as fast as LU.
- **Eigenvalues / eigenvectors** — QR algorithm, power iteration, Jacobi rotations.
- **SVD** — Singular Value Decomposition; the swiss-army knife of linear algebra.
- **Sparse matrices** — CSR/CSC storage, sparse `*`, sparse linear solvers.

### Interpolation

- **Cubic spline** (natural, clamped, not-a-knot).
- **Hermite interpolation** — uses derivatives at interpolation points.
- **Lagrange interpolation** — closed form via the Lagrange basis polynomials.
- **Barycentric Lagrange** — numerically stable evaluation.

### Special functions

- **Gamma, log-gamma, digamma, beta** — needed for statistics, combinatorics.
- **Erf, erfc, inverse erf** — for normal-distribution CDF/PPF.
- **Bessel functions** — wave physics, signal processing.

### Polynomial operations

- **Horner evaluation** — numerically stable.
- **Roots of polynomials** — companion matrix eigenvalues, or specialised cubic / quartic.
- **Least squares polynomial fit** — Vandermonde + QR.

### FFT

- **Discrete Fourier Transform** and inverse — Cooley-Tukey radix-2 / mixed radix.
- **Real-input FFT** — half the storage / half the work for real signals.
- **Convolution** via FFT.

### Random sampling

- **Distributions** — uniform, normal, exponential, gamma, beta, Poisson, binomial.
- **Quasi-random sequences** — Sobol, Halton for low-discrepancy sampling.
- **Monte Carlo integration** — using the above + variance reduction techniques.

### Decision rule for adding any of the above

We don't add things speculatively. Each addition needs **either** (a) a concrete consumer use case that would otherwise have to roll its own, or (b) a clear conceptual gap whose absence makes the library feel incomplete to its target audience. The author-name convention applies — `Newton`, `Gauss`, `Simpson`, `Cooley-Tukey`, etc. — and the namespace-vs-flat rule applies.
