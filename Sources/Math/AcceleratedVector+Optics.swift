// SPDX-License-Identifier: Apache-2.0

import CoreFP

// Optics into an `AcceleratedVector`'s components. They're FP's `[Double]` optics behind a
// lens onto the storage, so writes land in the buffer in place (no copy of the vector, no
// allocation unless the buffer is shared).

public extension AcceleratedVector {
    /// Every component, in order.
    static var each: Traversal<AcceleratedVector, Double> {
        storageLens.compose([Double].each)
    }

    /// The component at `index`, or nothing when it's out of bounds.
    static func ix(_ index: Int) -> AffineTraversal<AcceleratedVector, Double> {
        storageLens.compose([Double].ix(index))
    }
}

extension AcceleratedVector {
    /// The storage, writable in place. Internal: the vector has no invariant on its length,
    /// but the public surface stays the two optics above.
    static var storageLens: Lens<AcceleratedVector, [Double]> {
        Lens(
            get: { @Sendable in $0.storage },
            set: { @Sendable (vector: consuming AcceleratedVector, storage: [Double]) in
                var copy = consume vector
                copy.storage = storage
                return copy
            },
            modifyMut: { @Sendable vector, f in f(&vector.storage) }
        )
    }
}
