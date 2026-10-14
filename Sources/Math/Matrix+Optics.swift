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
        Traversal(
            forEach: { @Sendable matrix, body in
                let (length, stride) = (Swift.min(matrix.rows, matrix.columns), matrix.columns + 1)
                matrix.entries.withUnsafeBufferPointer { buffer in
                    for i in 0 ..< length {
                        body(buffer[i * stride])
                    }
                }
            },
            modifyMut: { @Sendable matrix, f in
                let (length, stride) = (Swift.min(matrix.rows, matrix.columns), matrix.columns + 1)
                matrix.entries.withUnsafeMutableBufferPointer { buffer in
                    for i in 0 ..< length {
                        f(&buffer[i * stride])
                    }
                }
            }
        )
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

    func contains(row: Int, column: Int) -> Bool {
        (0 ..< rows).contains(row) && (0 ..< columns).contains(column)
    }
}
