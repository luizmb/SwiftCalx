// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
import RealNumber

public struct Fibonacci: Sendable {
    public enum Method: Sendable {
        case precise, quick, balanced
    }

    public let method: Method

    public init(method: Method) {
        self.method = method
    }
}

extension Fibonacci: Sequence {
    public typealias Element = Double
    public func makeIterator() -> Iterator {
        .init(method: method)
    }

    public class Iterator: IteratorProtocol {
        public typealias Element = Double
        private var idx: Double = 0
        private let method: Method
        fileprivate init(method: Method) {
            self.method = method
        }

        public func next() -> Double? {
            let element = switch method {
            case .balanced: Fibonacci.balancedMethod(idx)
            case .precise: Fibonacci.preciseMethod(idx)
            case .quick: Fibonacci.quickMethod(idx)
            }
            idx += 1
            return element
        }
    }
}

public extension Fibonacci {
    static var quickMethod: Fn<Double> {
        Fn { x in
            let squareRootOfFive = sqrt(5)
            let onePlusSquareRootOfFive = 1 + squareRootOfFive
            return (1 / squareRootOfFive) * (
                pow(onePlusSquareRootOfFive / 2, x)
                    - pow(2 / onePlusSquareRootOfFive, x) * cos(x * Double.pi)
            )
        }
    }

    static var balancedMethod: Fn<Double> {
        Fn { x in
            guard x > 1 else { return x }
            let goldenRatio = (1.0 + pow(5.0, 0.5)) / 2.0

            func fibGoldenRec(_ depth: Double, _ n: Double) -> Double {
                if depth <= 2 {
                    return n
                }
                return fibGoldenRec(depth - 1, Double(round(Double(n) * goldenRatio)))
            }
            return fibGoldenRec(x, 1)
        }
    }

    static var preciseMethod: Fn<Double> {
        Fn { x in
            guard x > 1 else { return x }
            var current: Double = 1
            var previous: Double = 0
            for _ in stride(from: 2, through: x, by: 1) {
                let backupCurrent = current
                current += previous
                previous = backupCurrent
            }
            return current
        }
    }
}
