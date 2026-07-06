# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
