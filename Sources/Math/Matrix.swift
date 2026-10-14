// SPDX-License-Identifier: Apache-2.0

import RealNumber

/// A row-major rectangular matrix over an ``ℝ`` scalar.
///
/// `Matrix` is the value-type carrier behind every linear-algebra operation in this
/// library — Birchall's scaling-and-squaring, Taylor expansions of `exp(A)`, and so on
/// rely on it. It stores its entries in a single contiguous `[Scalar]` row-major, so
/// `self[i, j]` reads as `storage[i * columns + j]`.
///
/// ## Why row-major?
///
/// Most introductory texts (Strang's *Introduction to Linear Algebra*, Trefethen &
/// Bau's *Numerical Linear Algebra*) write matrices as
/// `[[a_{1,1}, a_{1,2}, …], [a_{2,1}, …], …]` — a list of rows. Row-major storage
/// keeps that mental model: walking through `storage` walks across each row in turn.
/// (BLAS defaults to column-major, the Fortran convention; we deliberately don't,
/// to keep `subscript(i, j)` cache-friendly *and* visually consistent with how
/// matrices are taught.)
///
/// ## Mutation
///
/// `Matrix` is a value: its entries can't be set from outside. Use
/// ``with(row:column:value:)`` to obtain a new matrix with one entry changed. For bulk
/// construction, build the `[Scalar]` storage first and hand it to the initializer in one
/// call — this matches how `Array` is conventionally built before being wrapped in a value
/// type. The compound operators (`+=`, `-=`, `*=` by a scalar) write into the existing
/// storage instead of building a new one.
public struct Matrix<Scalar: ℝ>: Equatable, Sendable where Scalar: Sendable {
    /// Number of rows. Always non-negative.
    public let rows: Int

    /// Number of columns. Always non-negative.
    public let columns: Int

    /// Row-major entries. Length is `rows * columns`. Reading `self[i, j]` is
    /// `storage[i * columns + j]`.
    @inlinable
    public var storage: [Scalar] { entries }

    /// The entries, writable only inside the module so the compound operators can update
    /// them in place.
    @usableFromInline
    var entries: [Scalar]

    /// Constructs a matrix from its dimensions and the flat row-major buffer.
    /// The caller is expected to provide a buffer of length `rows * columns`; out-of-range
    /// subscript access falls back to `Array`'s standard fatal trap (this matches the rest
    /// of the library — we don't add precondition checks for programmer errors).
    @inlinable
    public init(rows: Int, columns: Int, storage: [Scalar]) {
        self.rows = rows
        self.columns = columns
        entries = storage
    }

    /// O(1) read of the entry at row `i`, column `j`. Row-major lookup.
    @inlinable
    public subscript(row: Int, column: Int) -> Scalar {
        entries[row * columns + column]
    }

    /// The `n × n` matrix of all zeros.
    @inlinable
    public static func zero(size n: Int) -> Matrix {
        Matrix(rows: n, columns: n, storage: Array(repeating: 0, count: n * n))
    }

    /// The `n × n` identity matrix `Iₙ`: ones along the main diagonal, zeros elsewhere.
    /// Satisfies `Iₙ · M = M = M · Iₙ` for every conformable `M`.
    @inlinable
    public static func identity(size n: Int) -> Matrix {
        Matrix(
            rows: n,
            columns: n,
            storage: (0 ..< n * n).map { $0 / n == $0 % n ? 1 : 0 }
        )
    }

    /// Returns a copy of this matrix with the entry at `(row, column)` replaced by `value`.
    /// All other entries are unchanged. The original matrix is untouched.
    @inlinable
    public func with(row: Int, column: Int, value: Scalar) -> Matrix {
        var copy = self
        copy.entries[row * columns + column] = value
        return copy
    }

    /// Returns `self` squared `n` times: `((self²)²)²…`.
    ///
    /// Each squaring doubles the exponent, so `self.squared(times: k)` is mathematically
    /// `self^(2^k)`. `squared(times: 0)` returns `self` unchanged; `squared(times: 1)`
    /// returns `self · self`; `squared(times: 3)` returns `self^8`.
    ///
    /// This is the *undo* step of Birchall's scaling-and-squaring (and of any
    /// scaling-and-squaring matrix-exponential variant): after computing `exp(A / 2^k)`
    /// via Taylor series, squaring `k` times recovers `exp(A) = (exp(A / 2^k))^(2^k)`.
    /// See ``Birchall/matrixExponential(_:tolerance:maxIterations:)``.
    ///
    /// Alternates between two buffers, so `k` squarings allocate two matrices, not `k`.
    @inlinable
    public func squared(times n: Int) -> Matrix {
        var current = self
        var next = Matrix(rows: 0, columns: 0, storage: [])
        for _ in 0 ..< n {
            Matrix.multiply(current, current, into: &next)
            swap(&current, &next)
        }
        return current
    }
}
