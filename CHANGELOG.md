# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `VectorState.add(_:scaledBy:)`: `self = self + scalar * other` in place. Default implementation
  through the operators, so existing conformers keep compiling; `Array` and `AcceleratedVector`
  write into their buffer.
- `Matrix.multiply(_:_:into:)`: matrix product into a reused buffer.
- Matrix optics: `Matrix.each`, `Matrix.diagonal` (`Traversal`), `Matrix.entry(row:column:)`
  (`AffineTraversal`). Writes go into the buffer in place.
- `BenchmarkSuite/`: package-benchmark suite for the matrix and ODE hot paths.

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
