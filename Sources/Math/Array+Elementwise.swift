// SPDX-License-Identifier: Apache-2.0

import RealNumber

// Elementwise kernels shared by `Matrix` and the `Array: VectorState` conformance. Buffer
// loops instead of `zip(…).map`: once a caller specialises them (they're `@inlinable`), they
// compile to plain loops with no iterator, closure context or per-element allocation.
// Mismatched lengths behave like `zip`: the result is as long as the shorter operand.

extension Array where Element: ℝ {
    /// `[combine(self[i], other[i])]`, built in one allocation.
    @inlinable
    func elementwise(_ other: [Element], _ combine: (Element, Element) -> Element) -> [Element] {
        let length = Swift.min(count, other.count)
        return withUnsafeBufferPointer { lhs in
            other.withUnsafeBufferPointer { rhs in
                [Element](unsafeUninitializedCapacity: length) { result, initialized in
                    for index in 0 ..< length {
                        result.initializeElement(at: index, to: combine(lhs[index], rhs[index]))
                    }
                    initialized = length
                }
            }
        }
    }

    /// `[scalar * self[i]]`, built in one allocation.
    @inlinable
    func scaled(by scalar: Element) -> [Element] {
        withUnsafeBufferPointer { source in
            [Element](unsafeUninitializedCapacity: source.count) { result, initialized in
                for index in source.indices {
                    result.initializeElement(at: index, to: scalar * source[index])
                }
                initialized = source.count
            }
        }
    }

    /// `self[i] = combine(self[i], other[i])`, in place (no allocation unless the buffer is
    /// shared). Like ``elementwise(_:_:)``, the result is as long as the shorter operand.
    @inlinable
    mutating func formElementwise(_ other: [Element], _ combine: (Element, Element) -> Element) {
        let length = Swift.min(count, other.count)
        if count > length {
            removeLast(count - length)
        }
        withUnsafeMutableBufferPointer { lhs in
            other.withUnsafeBufferPointer { rhs in
                for index in 0 ..< length {
                    lhs[index] = combine(lhs[index], rhs[index])
                }
            }
        }
    }

    /// `self[i] = scalar * self[i]`, in place.
    @inlinable
    mutating func formScaled(by scalar: Element) {
        withUnsafeMutableBufferPointer { buffer in
            for index in buffer.indices {
                buffer[index] = scalar * buffer[index]
            }
        }
    }
}
