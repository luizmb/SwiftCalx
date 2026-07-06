// SPDX-License-Identifier: Apache-2.0

import RealNumber

public extension Matrix {
    /// Elementwise sum. `(A + B)[i, j] = A[i, j] + B[i, j]`.
    ///
    /// Both matrices must have the same shape; the result inherits that shape.
    static func + (lhs: Matrix, rhs: Matrix) -> Matrix {
        Matrix(
            rows: lhs.rows,
            columns: lhs.columns,
            storage: zip(lhs.storage, rhs.storage).map(+)
        )
    }

    /// In-place elementwise sum. Equivalent to `lhs = lhs + rhs`.
    static func += (lhs: inout Matrix, rhs: Matrix) {
        lhs = lhs + rhs
    }

    /// Elementwise difference. `(A − B)[i, j] = A[i, j] − B[i, j]`.
    ///
    /// Both matrices must have the same shape; the result inherits that shape.
    static func - (lhs: Matrix, rhs: Matrix) -> Matrix {
        Matrix(
            rows: lhs.rows,
            columns: lhs.columns,
            storage: zip(lhs.storage, rhs.storage).map(-)
        )
    }

    /// In-place elementwise difference. Equivalent to `lhs = lhs - rhs`.
    static func -= (lhs: inout Matrix, rhs: Matrix) {
        lhs = lhs - rhs
    }

    /// Scalar–matrix multiplication. `(α · A)[i, j] = α · A[i, j]`.
    ///
    /// Used to scale a coefficient matrix by time (e.g. `t · A` in `exp(t · A)`).
    static func * (scalar: Scalar, matrix: Matrix) -> Matrix {
        Matrix(
            rows: matrix.rows,
            columns: matrix.columns,
            storage: matrix.storage.map { scalar * $0 }
        )
    }

    /// In-place scalar multiplication. Equivalent to `lhs = scalar * lhs`.
    static func *= (lhs: inout Matrix, scalar: Scalar) {
        lhs = scalar * lhs
    }

    /// Matrix–matrix multiplication. `(A · B)[i, j] = Σₖ A[i, k] · B[k, j]`.
    ///
    /// Requires `lhs.columns == rhs.rows`; the result has shape `lhs.rows × rhs.columns`.
    /// This is the standard textbook definition (Strang, *Introduction to Linear Algebra*,
    /// Ch. 2.4). The implementation is a triple loop — O(n³) — which is fine for the
    /// small matrices these algorithms target (typically n < 50). For larger problems,
    /// drop in BLAS via Apple's Accelerate framework.
    static func * (lhs: Matrix, rhs: Matrix) -> Matrix {
        let storage = (0 ..< lhs.rows).flatMap { i in
            (0 ..< rhs.columns).map { j in
                (0 ..< lhs.columns).reduce(0) { acc, k in acc + lhs[i, k] * rhs[k, j] }
            }
        }
        return Matrix(rows: lhs.rows, columns: rhs.columns, storage: storage)
    }

    /// In-place matrix multiplication. Equivalent to `lhs = lhs * rhs`.
    ///
    /// Requires `lhs.columns == rhs.rows`. For non-square `rhs`, `lhs` may change
    /// shape (rows preserved, columns become `rhs.columns`).
    static func *= (lhs: inout Matrix, rhs: Matrix) {
        lhs = lhs * rhs
    }

    /// Matrix–vector application. Treats `vector` as a column and computes `A · v`.
    ///
    /// `(A · v)[i] = Σⱼ A[i, j] · v[j]`. The result has length `rows`.
    ///
    /// This is the linear-map view: `A` *acts on* `v` to produce another vector. The
    /// derivative of a linear ODE `dy/dt = A · y` is exactly this operation.
    func apply(to vector: [Scalar]) -> [Scalar] {
        (0 ..< rows).map { i in
            (0 ..< columns).reduce(0) { acc, j in acc + self[i, j] * vector[j] }
        }
    }
}
