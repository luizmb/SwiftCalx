// SPDX-License-Identifier: Apache-2.0

import RealNumber

// Overloads are picked at compile time, so code generic over `Scalar` (the `⋅` operator,
// `Matrix.Product`, `squared(times:)`, `actions(on:count:)`, a caller's own generic code) would
// never reach the `Scalar == Double` / `Float` BLAS overloads in `Matrix+BLAS.swift`. The
// generic `*` (through `productKernel`) and `apply(to:)` below check for those scalars first.
// Once specialised, the checks fold away; in unspecialised code they cost a type comparison.

public extension Matrix {
    /// Elementwise sum. `(A + B)[i, j] = A[i, j] + B[i, j]`.
    ///
    /// Both matrices must have the same shape; the result inherits that shape. Shapes aren't
    /// checked (nothing traps): with mismatched shapes the result keeps `lhs`'s shape over
    /// `min` of the two entry counts, which isn't a meaningful matrix. Check shapes first.
    @inlinable
    static func + (lhs: Matrix, rhs: Matrix) -> Matrix {
        Matrix(rows: lhs.rows, columns: lhs.columns, storage: lhs.entries.elementwise(rhs.entries, +))
    }

    /// In-place elementwise sum. Same result as `lhs = lhs + rhs`, written into `lhs`'s
    /// storage (no allocation unless that storage is shared).
    @inlinable
    static func += (lhs: inout Matrix, rhs: Matrix) {
        lhs.entries.formElementwise(rhs.entries, +)
    }

    /// Elementwise difference. `(A − B)[i, j] = A[i, j] − B[i, j]`.
    ///
    /// Both matrices must have the same shape; the result inherits that shape. Shapes aren't
    /// checked: see `+`.
    @inlinable
    static func - (lhs: Matrix, rhs: Matrix) -> Matrix {
        Matrix(rows: lhs.rows, columns: lhs.columns, storage: lhs.entries.elementwise(rhs.entries, -))
    }

    /// In-place elementwise difference. Same result as `lhs = lhs - rhs`, written into
    /// `lhs`'s storage.
    @inlinable
    static func -= (lhs: inout Matrix, rhs: Matrix) {
        lhs.entries.formElementwise(rhs.entries, -)
    }

    /// Scalar–matrix multiplication. `(α · A)[i, j] = α · A[i, j]`.
    ///
    /// Used to scale a coefficient matrix by time (e.g. `t · A` in `exp(t · A)`).
    @inlinable
    static func * (scalar: Scalar, matrix: Matrix) -> Matrix {
        Matrix(rows: matrix.rows, columns: matrix.columns, storage: matrix.entries.scaled(by: scalar))
    }

    /// In-place scalar multiplication. Same result as `lhs = scalar * lhs`, written into
    /// `lhs`'s storage.
    @inlinable
    static func *= (lhs: inout Matrix, scalar: Scalar) {
        lhs.entries.formScaled(by: scalar)
    }

    /// Matrix–matrix multiplication. `(A · B)[i, j] = Σₖ A[i, k] · B[k, j]`.
    ///
    /// Requires `lhs.columns == rhs.rows`; the result has shape `lhs.rows × rhs.columns`.
    /// This is the standard textbook definition (Strang, *Introduction to Linear Algebra*,
    /// Ch. 2.4). Where Accelerate is available, `Double` and `Float` matrices use BLAS
    /// (`cblas_dgemm` / `cblas_sgemm`), also when the caller is generic over `Scalar`.
    /// Everywhere else it's a triple loop — O(n³) — over the flat buffers, in `i, k, j`
    /// order so the inner loop walks both `rhs` and the result row by row. Each entry still
    /// sums its products in `k` order, starting from zero.
    @inlinable
    static func * (lhs: Matrix, rhs: Matrix) -> Matrix {
        var product = Matrix(rows: 0, columns: 0, storage: [])
        multiply(lhs, rhs, into: &product)
        return product
    }

    /// Writes `lhs · rhs` into `result`, reusing `result`'s buffer when it already has
    /// `lhs.rows * rhs.columns` entries and isn't shared: a loop that keeps two matrices and
    /// alternates between them (`squared(times:)`, a Taylor series) allocates nothing after
    /// its first products. `result` takes the product's shape.
    ///
    /// Pass a matrix other than `lhs` and `rhs` as `result`; passing one of them is correct
    /// but its buffer is shared with the operand, so the write copies it.
    @inlinable
    static func multiply(_ lhs: Matrix, _ rhs: Matrix, into result: inout Matrix) {
        let (rows, inner, columns) = (lhs.rows, lhs.columns, rhs.columns)
        var buffer: [Scalar] = []
        swap(&buffer, &result.entries)
        if buffer.count != rows * columns {
            buffer = [Scalar](repeating: .zero, count: rows * columns)
        }
        lhs.entries.withUnsafeBufferPointer { a in
            rhs.entries.withUnsafeBufferPointer { b in
                buffer.withUnsafeMutableBufferPointer { c in
                    productKernel(a, b, into: c, rows: rows, inner: inner, columns: columns)
                }
            }
        }
        result = Matrix(rows: rows, columns: columns, storage: buffer)
    }

    /// `c = a · b` over flat row-major buffers. BLAS for `Double` / `Float` where Accelerate
    /// is available; otherwise an `i, k, j` loop (the inner loop walks `b` and `c` row by
    /// row), each entry summing its products in `k` order from zero.
    @inlinable
    internal static func productKernel(
        _ a: UnsafeBufferPointer<Scalar>,
        _ b: UnsafeBufferPointer<Scalar>,
        into c: UnsafeMutableBufferPointer<Scalar>,
        rows: Int,
        inner: Int,
        columns: Int
    ) {
        #if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
            if acceleratedProduct(a, b, into: c, rows: rows, inner: inner, columns: columns) { return }
        #endif
        for index in c.indices {
            c[index] = .zero
        }
        for i in 0 ..< rows {
            for k in 0 ..< inner {
                let aik = a[i * inner + k]
                for j in 0 ..< columns {
                    c[i * columns + j] += aik * b[k * columns + j]
                }
            }
        }
    }

    /// In-place matrix multiplication. Equivalent to `lhs = lhs * rhs`.
    ///
    /// Requires `lhs.columns == rhs.rows`. For non-square `rhs`, `lhs` may change
    /// shape (rows preserved, columns become `rhs.columns`).
    @inlinable
    static func *= (lhs: inout Matrix, rhs: Matrix) {
        lhs = lhs * rhs
    }

    /// Matrix–vector application. Treats `vector` as a column and computes `A · v`.
    ///
    /// `(A · v)[i] = Σⱼ A[i, j] · v[j]`. The result has length `rows`.
    ///
    /// This is the linear-map view: `A` *acts on* `v` to produce another vector. The
    /// derivative of a linear ODE `dy/dt = A · y` is exactly this operation.
    ///
    /// Where Accelerate is available, `Double` and `Float` use BLAS (`cblas_dgemv` /
    /// `cblas_sgemv`), also when the caller is generic over `Scalar`.
    @inlinable
    func apply(to vector: [Scalar]) -> [Scalar] {
        #if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
            if Scalar.self == Double.self, let m = self as? Matrix<Double>, let x = vector as? [Double],
               let product = m.apply(to: x) as? [Scalar] {
                return product
            }
            if Scalar.self == Float.self, let m = self as? Matrix<Float>, let x = vector as? [Float],
               let product = m.apply(to: x) as? [Scalar] {
                return product
            }
        #endif
        let (rows, columns) = (rows, columns)
        return entries.withUnsafeBufferPointer { a in
            vector.withUnsafeBufferPointer { x in
                [Scalar](unsafeUninitializedCapacity: rows) { y, initialized in
                    for i in 0 ..< rows {
                        var sum: Scalar = .zero
                        for j in 0 ..< columns {
                            sum += a[i * columns + j] * x[j]
                        }
                        y.initializeElement(at: i, to: sum)
                    }
                    initialized = rows
                }
            }
        }
    }
}
