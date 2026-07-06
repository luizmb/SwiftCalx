// SPDX-License-Identifier: Apache-2.0

import RealNumber

#if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
    import Accelerate
#endif

// MARK: - VectorState / NormedVectorState conformance

//
// These conformances are the whole reason `AcceleratedVector` exists: the protocol
// witnesses for `+` and `*` go through the optimised path below, which means
// every generic-over-`VectorState` consumer (RK45, RK4, Birchall's iterated
// action, future solvers) automatically picks up the speedup when their
// state is `AcceleratedVector`.

extension AcceleratedVector: VectorState {
    public typealias Scalar = Double

    public static func + (lhs: AcceleratedVector, rhs: AcceleratedVector) -> AcceleratedVector {
        #if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
            let n = lhs.storage.count
            var result = [Double](repeating: 0, count: n)
            lhs.storage.withUnsafeBufferPointer { lBuf in
                rhs.storage.withUnsafeBufferPointer { rBuf in
                    result.withUnsafeMutableBufferPointer { resBuf in
                        if let l = lBuf.baseAddress, let r = rBuf.baseAddress, let res = resBuf.baseAddress {
                            vDSP_vaddD(l, 1, r, 1, res, 1, vDSP_Length(n))
                        }
                    }
                }
            }
            return AcceleratedVector(result)
        #else
            return AcceleratedVector(Swift.zip(lhs.storage, rhs.storage).map(+))
        #endif
    }

    public static func * (scalar: Double, vector: AcceleratedVector) -> AcceleratedVector {
        #if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
            let n = vector.storage.count
            var result = [Double](repeating: 0, count: n)
            var alpha = scalar
            vector.storage.withUnsafeBufferPointer { vBuf in
                result.withUnsafeMutableBufferPointer { resBuf in
                    if let v = vBuf.baseAddress, let res = resBuf.baseAddress {
                        vDSP_vsmulD(v, 1, &alpha, res, 1, vDSP_Length(n))
                    }
                }
            }
            return AcceleratedVector(result)
        #else
            return AcceleratedVector(vector.storage.map { scalar * $0 })
        #endif
    }
}

extension AcceleratedVector: NormedVectorState {
    public var infinityNorm: Double {
        #if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
            var result = 0.0
            storage.withUnsafeBufferPointer { buf in
                if let p = buf.baseAddress {
                    vDSP_maxmgvD(p, 1, &result, vDSP_Length(storage.count))
                }
            }
            return result
        #else
            return storage.reduce(0.0) { acc, x in
                let mag = x < 0 ? -x : x
                return mag > acc ? mag : acc
            }
        #endif
    }
}

// MARK: - Additional ergonomic arithmetic (subtraction + in-place forms)

public extension AcceleratedVector {
    static func - (lhs: AcceleratedVector, rhs: AcceleratedVector) -> AcceleratedVector {
        #if canImport(Accelerate) && !SWIFTCALX_NO_ACCELERATE
            // vDSP_vsubD: result = b - a (note the argument order — swap to get lhs - rhs).
            let n = lhs.storage.count
            var result = [Double](repeating: 0, count: n)
            lhs.storage.withUnsafeBufferPointer { lBuf in
                rhs.storage.withUnsafeBufferPointer { rBuf in
                    result.withUnsafeMutableBufferPointer { resBuf in
                        if let l = lBuf.baseAddress, let r = rBuf.baseAddress, let res = resBuf.baseAddress {
                            vDSP_vsubD(r, 1, l, 1, res, 1, vDSP_Length(n))
                        }
                    }
                }
            }
            return AcceleratedVector(result)
        #else
            let result: [Double] = Swift.zip(lhs.storage, rhs.storage).map { $0 - $1 }
            return AcceleratedVector(result)
        #endif
    }

    static func += (lhs: inout AcceleratedVector, rhs: AcceleratedVector) { lhs = lhs + rhs }
    static func -= (lhs: inout AcceleratedVector, rhs: AcceleratedVector) { lhs = lhs - rhs }
    static func *= (lhs: inout AcceleratedVector, scalar: Double) { lhs = scalar * lhs }
}
