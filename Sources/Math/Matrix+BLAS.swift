// SPDX-License-Identifier: Apache-2.0

// Hardware-accelerated specializations for the hot matrix operations.
//
// Build-time backend selection:
// - Apple platforms with Accelerate available (the default everywhere except
//   Linux/Windows): the cblas / vDSP path. Use `#if canImport(Accelerate)`.
//   Override with `-D SWIFTCALX_NO_ACCELERATE` to force the scalar fallback
//   (useful for testing/benchmarking that the fallback stays correct on Apple
//   hardware).
// - Everything else (Linux, WASM, anywhere `Accelerate` is unavailable):
//   the existing scalar Swift loops in `Matrix+Arithmetic.swift`. No-op — the
//   generic versions in that file just run as-is.
//
// OpenBLAS integration for Linux is tracked as a future iteration in
// MIGRATION_PLAN — the same-repo conditional-target design doesn't work
// cleanly because SwiftPM tries to build the system library target on any
// Linux build, regardless of whether the user has OpenBLAS installed. The
// cleaner shape is a separate bridge package consumers add explicitly.

#if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
    import Accelerate
#endif

#if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE

    // MARK: - Matrix * vector (mat-vec)

    public extension Matrix where Scalar == Double {
        /// BLAS-accelerated `apply(to:)`. `cblas_dgemv` is Accelerate's
        /// hand-tuned matrix-vector product, using NEON/AMX kernels on M-series.
        /// Result is numerically equivalent to the scalar `apply(to:)` up to
        /// floating-point accumulation order.
        func apply(to vector: [Double]) -> [Double] {
            guard rows > 0, columns > 0 else { return Array(repeating: 0, count: rows) }
            var result = [Double](repeating: 0, count: rows)
            storage.withUnsafeBufferPointer { aBuf in
                vector.withUnsafeBufferPointer { xBuf in
                    result.withUnsafeMutableBufferPointer { yBuf in
                        if let a = aBuf.baseAddress, let x = xBuf.baseAddress, let y = yBuf.baseAddress {
                            cblas_dgemv(
                                CblasRowMajor,
                                CblasNoTrans,
                                Int32(rows),
                                Int32(columns),
                                1.0,
                                a,
                                Int32(columns),
                                x,
                                1,
                                0.0,
                                y,
                                1
                            )
                        }
                    }
                }
            }
            return result
        }
    }

    public extension Matrix where Scalar == Float {
        /// `cblas_sgemv` analogue of ``Matrix/apply(to:)-9wzs`` for `Float`.
        func apply(to vector: [Float]) -> [Float] {
            guard rows > 0, columns > 0 else { return Array(repeating: 0, count: rows) }
            var result = [Float](repeating: 0, count: rows)
            storage.withUnsafeBufferPointer { aBuf in
                vector.withUnsafeBufferPointer { xBuf in
                    result.withUnsafeMutableBufferPointer { yBuf in
                        if let a = aBuf.baseAddress, let x = xBuf.baseAddress, let y = yBuf.baseAddress {
                            cblas_sgemv(
                                CblasRowMajor,
                                CblasNoTrans,
                                Int32(rows),
                                Int32(columns),
                                1.0,
                                a,
                                Int32(columns),
                                x,
                                1,
                                0.0,
                                y,
                                1
                            )
                        }
                    }
                }
            }
            return result
        }
    }

    // MARK: - Matrix * matrix (mat-mat)

    public extension Matrix where Scalar == Double {
        /// BLAS-accelerated matrix-matrix product. `cblas_dgemm` does cache blocking,
        /// per-chip kernel selection, and (on M-series Macs) uses the AMX
        /// coprocessor — typically 5–20× faster than the naive triple-loop for
        /// the matrix sizes that show up in biokinetic / linear-algebra workloads,
        /// and dramatically more for larger matrices.
        static func * (lhs: Matrix, rhs: Matrix) -> Matrix {
            guard lhs.rows > 0, rhs.columns > 0, lhs.columns > 0 else {
                return Matrix(rows: lhs.rows, columns: rhs.columns, storage: Array(repeating: 0, count: lhs.rows * rhs.columns))
            }
            var result = [Double](repeating: 0, count: lhs.rows * rhs.columns)
            lhs.storage.withUnsafeBufferPointer { aBuf in
                rhs.storage.withUnsafeBufferPointer { bBuf in
                    result.withUnsafeMutableBufferPointer { cBuf in
                        if let a = aBuf.baseAddress, let b = bBuf.baseAddress, let c = cBuf.baseAddress {
                            cblas_dgemm(
                                CblasRowMajor,
                                CblasNoTrans,
                                CblasNoTrans,
                                Int32(lhs.rows),
                                Int32(rhs.columns),
                                Int32(lhs.columns),
                                1.0,
                                a,
                                Int32(lhs.columns),
                                b,
                                Int32(rhs.columns),
                                0.0,
                                c,
                                Int32(rhs.columns)
                            )
                        }
                    }
                }
            }
            return Matrix(rows: lhs.rows, columns: rhs.columns, storage: result)
        }
    }

    public extension Matrix where Scalar == Float {
        /// `cblas_sgemm` analogue of ``*(_:_:)-1m3vn`` for `Float`.
        static func * (lhs: Matrix, rhs: Matrix) -> Matrix {
            guard lhs.rows > 0, rhs.columns > 0, lhs.columns > 0 else {
                return Matrix(rows: lhs.rows, columns: rhs.columns, storage: Array(repeating: 0, count: lhs.rows * rhs.columns))
            }
            var result = [Float](repeating: 0, count: lhs.rows * rhs.columns)
            lhs.storage.withUnsafeBufferPointer { aBuf in
                rhs.storage.withUnsafeBufferPointer { bBuf in
                    result.withUnsafeMutableBufferPointer { cBuf in
                        if let a = aBuf.baseAddress, let b = bBuf.baseAddress, let c = cBuf.baseAddress {
                            cblas_sgemm(
                                CblasRowMajor,
                                CblasNoTrans,
                                CblasNoTrans,
                                Int32(lhs.rows),
                                Int32(rhs.columns),
                                Int32(lhs.columns),
                                1.0,
                                a,
                                Int32(lhs.columns),
                                b,
                                Int32(rhs.columns),
                                0.0,
                                c,
                                Int32(rhs.columns)
                            )
                        }
                    }
                }
            }
            return Matrix(rows: lhs.rows, columns: rhs.columns, storage: result)
        }
    }

#endif

// MARK: - vDSP element-wise ops (Apple-only)

//
// vDSP element-wise vector kernels are part of Accelerate but have no direct
// OpenBLAS equivalent (cblas covers BLAS levels 1–3, not the vDSP-style
// elementwise / waveform primitives). On Linux the existing scalar Swift
// versions in `Matrix+Arithmetic.swift` remain in effect.

#if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE

    public extension Matrix where Scalar == Double {
        static func + (lhs: Matrix, rhs: Matrix) -> Matrix {
            elementwise(lhs, rhs, vDSP_vaddD)
        }

        static func - (lhs: Matrix, rhs: Matrix) -> Matrix {
            elementwise(lhs, rhs) { aPtr, _, bPtr, _, cPtr, _, n in
                // vDSP_vsubD computes (b - a), so swap arguments to get (a - b).
                vDSP_vsubD(bPtr, 1, aPtr, 1, cPtr, 1, n)
            }
        }

        static func * (scalar: Scalar, matrix: Matrix) -> Matrix {
            guard matrix.storage.isEmpty == false else { return matrix }
            var result = [Double](repeating: 0, count: matrix.storage.count)
            var alpha = scalar
            matrix.storage.withUnsafeBufferPointer { aBuf in
                result.withUnsafeMutableBufferPointer { cBuf in
                    if let a = aBuf.baseAddress, let c = cBuf.baseAddress {
                        vDSP_vsmulD(a, 1, &alpha, c, 1, vDSP_Length(matrix.storage.count))
                    }
                }
            }
            return Matrix(rows: matrix.rows, columns: matrix.columns, storage: result)
        }

        private static func elementwise(
            _ lhs: Matrix,
            _ rhs: Matrix,
            _ op: (
                UnsafePointer<Double>, vDSP_Stride,
                UnsafePointer<Double>, vDSP_Stride,
                UnsafeMutablePointer<Double>, vDSP_Stride,
                vDSP_Length
            ) -> Void
        ) -> Matrix {
            let count = lhs.storage.count
            guard count > 0 else { return lhs }
            var result = [Double](repeating: 0, count: count)
            lhs.storage.withUnsafeBufferPointer { aBuf in
                rhs.storage.withUnsafeBufferPointer { bBuf in
                    result.withUnsafeMutableBufferPointer { cBuf in
                        if let a = aBuf.baseAddress, let b = bBuf.baseAddress, let c = cBuf.baseAddress {
                            op(a, 1, b, 1, c, 1, vDSP_Length(count))
                        }
                    }
                }
            }
            return Matrix(rows: lhs.rows, columns: lhs.columns, storage: result)
        }
    }

    public extension Matrix where Scalar == Float {
        static func + (lhs: Matrix, rhs: Matrix) -> Matrix {
            elementwise(lhs, rhs, vDSP_vadd)
        }

        static func - (lhs: Matrix, rhs: Matrix) -> Matrix {
            elementwise(lhs, rhs) { aPtr, _, bPtr, _, cPtr, _, n in
                // vDSP_vsub computes (b - a), so swap arguments.
                vDSP_vsub(bPtr, 1, aPtr, 1, cPtr, 1, n)
            }
        }

        static func * (scalar: Scalar, matrix: Matrix) -> Matrix {
            guard matrix.storage.isEmpty == false else { return matrix }
            var result = [Float](repeating: 0, count: matrix.storage.count)
            var alpha = scalar
            matrix.storage.withUnsafeBufferPointer { aBuf in
                result.withUnsafeMutableBufferPointer { cBuf in
                    if let a = aBuf.baseAddress, let c = cBuf.baseAddress {
                        vDSP_vsmul(a, 1, &alpha, c, 1, vDSP_Length(matrix.storage.count))
                    }
                }
            }
            return Matrix(rows: matrix.rows, columns: matrix.columns, storage: result)
        }

        private static func elementwise(
            _ lhs: Matrix,
            _ rhs: Matrix,
            _ op: (
                UnsafePointer<Float>, vDSP_Stride,
                UnsafePointer<Float>, vDSP_Stride,
                UnsafeMutablePointer<Float>, vDSP_Stride,
                vDSP_Length
            ) -> Void
        ) -> Matrix {
            let count = lhs.storage.count
            guard count > 0 else { return lhs }
            var result = [Float](repeating: 0, count: count)
            lhs.storage.withUnsafeBufferPointer { aBuf in
                rhs.storage.withUnsafeBufferPointer { bBuf in
                    result.withUnsafeMutableBufferPointer { cBuf in
                        if let a = aBuf.baseAddress, let b = bBuf.baseAddress, let c = cBuf.baseAddress {
                            op(a, 1, b, 1, c, 1, vDSP_Length(count))
                        }
                    }
                }
            }
            return Matrix(rows: lhs.rows, columns: lhs.columns, storage: result)
        }
    }

#endif
