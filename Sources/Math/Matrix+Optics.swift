// SPDX-License-Identifier: Apache-2.0

import CoreFP
import RealNumber

// Optics into a matrix's entries. Every write goes straight into the row-major buffer:
// no copy of the matrix and no allocation, unless the buffer is shared with another value
// (then the first write copies it once, as any value type does).

public extension Matrix {
    /// Every entry, row by row. Reads and writes go through the flat buffer (it's FP's
    /// `[Scalar].each` behind a lens onto the storage), so `Matrix.each.over { 2 * $0 }`
    /// and `modifyMut` scale a uniquely owned matrix in place.
    static var each: Traversal<Matrix, Scalar> {
        storageLens.compose([Scalar].each)
    }

    /// The main diagonal `A[i, i]`, for `i < min(rows, columns)`. Folding it (`reduce`,
    /// `foldMap`, `count`) builds no array; writing it touches only those entries.
    static var diagonal: Traversal<Matrix, Scalar> {
        strided { matrix in (start: 0, count: Swift.min(matrix.rows, matrix.columns), stride: matrix.columns + 1) }
    }

    /// The entries of one row, left to right; nothing when the row is outside the matrix.
    static func row(_ index: Int) -> Traversal<Matrix, Scalar> {
        strided { matrix in
            (0 ..< matrix.rows).contains(index)
                ? (start: index * matrix.columns, count: matrix.columns, stride: 1)
                : (start: 0, count: 0, stride: 1)
        }
    }

    /// The entries of one column, top to bottom; nothing when the column is outside the
    /// matrix. In a compartmental model's coefficient matrix that's one compartment's
    /// inflow and outflow coefficients, editable in place.
    static func column(_ index: Int) -> Traversal<Matrix, Scalar> {
        strided { matrix in
            (0 ..< matrix.columns).contains(index)
                ? (start: index, count: matrix.rows, stride: matrix.columns)
                : (start: 0, count: 0, stride: 1)
        }
    }

    /// The entry at `(row, column)`, or nothing when it's outside the matrix (unlike the
    /// subscript, which traps). Writes land in the buffer in place.
    static func entry(row: Int, column: Int) -> AffineTraversal<Matrix, Scalar> {
        AffineTraversal(
            preview: { @Sendable matrix in
                matrix.contains(row: row, column: column) ? matrix.entries[row * matrix.columns + column] : nil
            },
            set: { @Sendable (matrix: consuming Matrix, value: Scalar) in
                var copy = consume matrix
                if copy.contains(row: row, column: column) {
                    copy.entries[row * copy.columns + column] = value
                }
                return copy
            },
            tryModifyMut: { @Sendable matrix, f in
                guard matrix.contains(row: row, column: column) else { return }
                let offset = row * matrix.columns + column
                matrix.entries.withUnsafeMutableBufferPointer { f(&$0[offset]) }
            }
        )
    }
}

extension Matrix {
    /// The flat storage, writable in place. Internal: only traversals that keep the count
    /// (`[Scalar].each`) are composed onto it, so `rows * columns` stays true.
    static var storageLens: Lens<Matrix, [Scalar]> {
        Lens(
            get: { @Sendable in $0.entries },
            set: { @Sendable (matrix: consuming Matrix, entries: [Scalar]) in
                var copy = consume matrix
                copy.entries = entries
                return copy
            },
            modifyMut: { @Sendable matrix, f in f(&matrix.entries) }
        )
    }

    /// A traversal over `count` entries of the flat buffer, `stride` apart from `start`:
    /// rows, columns and the diagonal are all this shape. Reads and writes go through the
    /// buffer, so they build no array and write in place.
    static func strided(
        _ layout: @escaping @Sendable (Matrix) -> (start: Int, count: Int, stride: Int)
    ) -> Traversal<Matrix, Scalar> {
        Traversal(
            forEach: { @Sendable matrix, body in
                let (start, count, stride) = layout(matrix)
                matrix.entries.withUnsafeBufferPointer { buffer in
                    for i in 0 ..< count {
                        body(buffer[start + i * stride])
                    }
                }
            },
            modifyMut: { @Sendable matrix, f in
                let (start, count, stride) = layout(matrix)
                matrix.entries.withUnsafeMutableBufferPointer { buffer in
                    for i in 0 ..< count {
                        f(&buffer[start + i * stride])
                    }
                }
            }
        )
    }

    func contains(row: Int, column: Int) -> Bool {
        (0 ..< rows).contains(row) && (0 ..< columns).contains(column)
    }
}
