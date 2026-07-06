// SPDX-License-Identifier: Apache-2.0

import Math
import RealNumber
#if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
    import Accelerate
#endif

// MARK: - Dot operator overloads for AcceleratedVector

//
// Extends the `⋅` operator family from `Matrix+Operators.swift` to cover
// `AcceleratedVector` interop. Reads naturally as it would on paper:
//   - `A ⋅ v`         matrix–vector apply, returns `AcceleratedVector` (was `[Scalar]`)
//   - `α ⋅ v`         scalar–vector multiply
//   - `u ⋅ v`         vector–vector dot product (Σ u_i · v_i)

/// Matrix-AcceleratedVector application, `AcceleratedVector` form. Equivalent to `matrix.apply(to: vector)`.
/// Bridges generic `⋅` callers into `AcceleratedVector`-land when the right-hand side is a `AcceleratedVector`.
public func ⋅ (matrix: Matrix<Double>, vector: AcceleratedVector) -> AcceleratedVector {
    matrix.apply(to: vector)
}

/// Scalar-vector multiplication. Equivalent to `scalar * vector`.
public func ⋅ (scalar: Double, vector: AcceleratedVector) -> AcceleratedVector {
    scalar * vector
}

/// AcceleratedVector-vector dot product: `Σ u_i · v_i`. Returns a single `Double`.
/// On Apple, routes through `cblas_ddot` (Accelerate's BLAS Level 1 dot
/// kernel — SIMD, register-tuned per chip). Falls back to a scalar
/// `zip + reduce` on non-Apple builds or `-D SWIFTCALX_NO_ACCELERATE`.
public func ⋅ (lhs: AcceleratedVector, rhs: AcceleratedVector) -> Double {
    #if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
        let n = Int32(lhs.storage.count)
        var result = 0.0
        lhs.storage.withUnsafeBufferPointer { lBuf in
            rhs.storage.withUnsafeBufferPointer { rBuf in
                if let l = lBuf.baseAddress, let r = rBuf.baseAddress {
                    result = cblas_ddot(n, l, 1, r, 1)
                }
            }
        }
        return result
    #else
        return zip(lhs.storage, rhs.storage).reduce(0.0) { $0 + $1.0 * $1.1 }
    #endif
}
