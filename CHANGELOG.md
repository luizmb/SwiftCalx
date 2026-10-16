# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `RungeKutta4.propagator(of:step:)` and `RungeKutta4.linearTrajectory(of:from:step:stepsPerSample:count:)`:
  RK4 on a linear, time-invariant system `dy/dt = A·y` as its propagator
  `P = I + hA + … + (hA)⁴/24`, raised once to the steps between samples and walked with one
  matrix-vector product per sample. Same method and truncation error as stepping it (tests pin
  it to `trajectory` on random compartment-like systems).
- `Matrix.raised(to:)`: integer power by repeated squaring, alternating buffers.
- `RungeKutta45.Failure` (`.stepLimit(reached:steps:)`, `.stepUnderflow(at:step:)`).

### Changed (breaking)
- `RungeKutta45.trajectory(at:…)` returns `Result<[State], RungeKutta45.Failure>` and
  `denseSegments(…)` returns `Result<[Segment<State>], RungeKutta45.Failure>`. They used to stop
  silently when `maxIterations` ran out (or the step fell below `minStep`) and answer every later
  output time with the last state reached: on a stiff 19-compartment model over 1 000 days the
  default budget ran out at day 836 and the last 165 days were a flat copy, 2.9e-4 off at a
  requested tolerance of 1e-10. Callers add `.get()` or switch on the result. The integration
  runs to `max(outputTimes)` (was `outputTimes.last`), as documented.

## [1.0.0] - 2026-10-15

### Added
- `VectorState.add(_:scaledBy:)`: `self = self + scalar * other` in place. Default implementation
  through the operators, so existing conformers keep compiling; `Array` and `AcceleratedVector`
  write into their buffer.
- `Matrix.multiply(_:_:into:)`: matrix product into a reused buffer.
- Matrix optics: `Matrix.each`, `Matrix.diagonal` (`Traversal`), `Matrix.entry(row:column:)`
  (`AffineTraversal`). Writes go into the buffer in place.
- `BenchmarkSuite/`: package-benchmark suite for the matrix and ODE hot paths.
- `RungeKutta4.calculateNextStateMut` / `calculateNextPointMut`: `reduce(into:)`-shaped twins
  of the trajectory appenders, linear over a run. The pure ones stay and take the trajectory
  `consuming`, so a handed-over trajectory is appended to without a copy.
- Optics: `Matrix.row(_:)`, `Matrix.column(_:)`, `AcceleratedVector.each`, `AcceleratedVector.ix(_:)`.
- `AcceleratedVector.reduce(into:_:)`.

### Changed
- Requires FP 3.0.0 (`from: "3.0.0"`).
- Hot generic code (`Matrix` arithmetic, `VectorState` for `Array`, RK4 / RK45 / Hermite,
  `SimpsonWeightedAverage`) is `@inlinable` buffer loops: specialised in the caller's module,
  no allocation per element. Results are bit-for-bit the same formulas (tests pin them).
- Generic callers of `Matrix` `*` and `apply(to:)` (`⋅`, `Matrix.Product`, `squared(times:)`,
  `actions(on:count:)`) reach BLAS for `Double` / `Float` on Apple. BLAS sums in its own
  order, so those results can differ from 0.6 in the last bits.
- `+=`, `-=`, `*=` (scalar) on `Matrix` and `AcceleratedVector` write in place.
- `squared(times:)` and `Taylor.exponential` alternate two buffers instead of allocating per step.
- `RungeKutta4.trajectory` appends in place (was O(n²) through `calculateNextState`).
- `AcceleratedVector` `liftA2`, `apply`, `seqLeft`, `seqRight`, `cartesian`, `concat`, `join`
  build their result in one allocation (no inner array per element).
- `Matrix.with(row:column:value:)` and `AcceleratedVector.combine` take the value `consuming`:
  a temporary or `consume x` is written into without a copy.
- `Matrix.identity` fills the diagonal of a zero matrix instead of computing every entry.

### Fixed
- Accelerate `Matrix` `+` / `-` (`Double`, `Float`), `AcceleratedVector` `+` / `-` and the
  `AcceleratedVector` `⋅` dot product read past the shorter operand when lengths differed;
  they now stop at the shorter one, like the Swift path.
- In-place `+=`, `-=` and `add(_:scaledBy:)` keep the shorter length, like `+` and `-`.

## [0.4.0] - 2026-07-05

### Changed
- CI: Linux now builds on the official `swift:6.3` container.

## [0.3.0] - 2026-05-23

### Added
- `AcceleratedVector` — hardware-accelerated vector state (Accelerate/vDSP) with a pure,
  non-throwing Collection / Functor / Monad / Foldable / Cartesian surface.
- Hardware-accelerated `Matrix` operations via Accelerate.
- RK45: `[Double]`-specialised trajectory with vDSP fused stage combination.

### Changed
- Renamed `Vector` → `AcceleratedVector`; moved `Monoid` conformance into the struct file.

## [0.2.0] - 2026-05-22

- Initial public release: ODE solvers (Runge–Kutta), numerical derivatives, matrix arithmetic,
  real-number protocol (`ℝ`), and vector states, built on `FP`.

[Unreleased]: https://github.com/luizmb/SwiftCalx/compare/v0.4.0...main
[0.4.0]: https://github.com/luizmb/SwiftCalx/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/luizmb/SwiftCalx/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/luizmb/SwiftCalx/releases/tag/v0.2.0
