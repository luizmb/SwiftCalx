// SPDX-License-Identifier: Apache-2.0

import Math
import XCTest

final class VectorFPTests: XCTestCase {
    // MARK: - Functor

    func testFmapIsCurriedMapVector() {
        let double = AcceleratedVector.fmap { $0 * 2 }
        XCTAssertEqual(double(AcceleratedVector([1.0, 2.0, 3.0])), AcceleratedVector([2.0, 4.0, 6.0]))
    }

    func testFmapComposesCleanly() {
        let plus1 = AcceleratedVector.fmap { $0 + 1 }
        let times2 = AcceleratedVector.fmap { $0 * 2 }
        let composed: (AcceleratedVector) -> AcceleratedVector = { v in times2(plus1(v)) }
        XCTAssertEqual(composed(AcceleratedVector([1.0, 2.0, 3.0])), AcceleratedVector([4.0, 6.0, 8.0]))
    }

    func testFmapGenericReturnsArray() {
        // Map Double → String exits AcceleratedVector-land; result is [String].
        let stringify: @Sendable (AcceleratedVector) -> [String] = AcceleratedVector.fmap { String($0) }
        XCTAssertEqual(stringify(AcceleratedVector([1.0, 2.0])), ["1.0", "2.0"])
    }

    func testInstanceMapToOtherTypeReturnsArray() {
        let v = AcceleratedVector([1.0, 2.0, 3.0])
        let ints: [Int] = v.map { Int($0) }
        XCTAssertEqual(ints, [1, 2, 3])
    }

    // MARK: - Monad

    func testBindFlattensVectorOfVectors() {
        // Each element x produces a 2-element vector [x, -x].
        let duplicate = AcceleratedVector.bind { x in AcceleratedVector([x, -x]) }
        XCTAssertEqual(duplicate(AcceleratedVector([1.0, 2.0])), AcceleratedVector([1.0, -1.0, 2.0, -2.0]))
    }

    func testKleisliComposesEffectfulFunctions() {
        let f: @Sendable (Double) -> AcceleratedVector = { x in AcceleratedVector([x, x + 1]) }
        let g: @Sendable (Double) -> AcceleratedVector = { x in AcceleratedVector([x * 10]) }
        let composed = AcceleratedVector.kleisli(f, g)
        // f(2) = [2, 3]; g applied to each = [20, 30]; flattened = [20, 30]
        XCTAssertEqual(composed(2.0), AcceleratedVector([20.0, 30.0]))
    }

    func testInstanceFlatMapTypePreserving() {
        let v = AcceleratedVector([1.0, 2.0])
        let duplicated = v.flatMap { AcceleratedVector([$0, -$0]) }
        XCTAssertEqual(duplicated, AcceleratedVector([1.0, -1.0, 2.0, -2.0]))
    }

    func testInstanceFlatMapToArray() {
        let v = AcceleratedVector([1.0, 2.0])
        let widened: [Int] = v.flatMap { [Int($0), Int($0) + 100] }
        XCTAssertEqual(widened, [1, 101, 2, 102])
    }

    func testJoinFlattensArrayOfVectors() {
        let nested = [AcceleratedVector([1.0, 2.0]), AcceleratedVector([3.0]), AcceleratedVector([4.0, 5.0])]
        XCTAssertEqual(AcceleratedVector.join(nested), AcceleratedVector([1.0, 2.0, 3.0, 4.0, 5.0]))
    }

    func testAltConcatenates() {
        let combined = AcceleratedVector.alt(AcceleratedVector([1.0, 2.0]), AcceleratedVector([3.0, 4.0]))
        XCTAssertEqual(combined, AcceleratedVector([1.0, 2.0, 3.0, 4.0]))
    }

    // MARK: - Semigroup / Monoid (regression — `[Double] + [Double]` is

    // elementwise due to `Array: VectorState`, so `combine` must use
    // explicit concatenation, not `+`).

    func testCombineConcatenatesNotElementwise() {
        let combined = AcceleratedVector.combine(AcceleratedVector([1.0, 2.0]), AcceleratedVector([3.0, 4.0]))
        XCTAssertEqual(combined, AcceleratedVector([1.0, 2.0, 3.0, 4.0]))
    }

    func testIdentityIsEmpty() {
        XCTAssertEqual(AcceleratedVector.identity, AcceleratedVector([]))
        let v = AcceleratedVector([1.0, 2.0])
        XCTAssertEqual(AcceleratedVector.combine(v, .identity), v)
        XCTAssertEqual(AcceleratedVector.combine(.identity, v), v)
    }

    // MARK: - Collection (pure non-throwing)

    func testCompactMapPure() {
        let v = AcceleratedVector([1.0, 2.0, 3.0, 4.0])
        let evens: [Double] = v.compactMap { $0.truncatingRemainder(dividingBy: 2) == 0 ? $0 : nil }
        XCTAssertEqual(evens, [2.0, 4.0])
    }

    func testFilterMIsCurriedFilter() {
        let positives = AcceleratedVector.filterM { $0 > 0 }
        XCTAssertEqual(positives(AcceleratedVector([1.0, -2.0, 3.0])), AcceleratedVector([1.0, 3.0]))
    }

    // MARK: - Applicative

    func testLiftA2DoesCartesianProduct() {
        let combine = AcceleratedVector.liftA2(+)
        XCTAssertEqual(
            combine(AcceleratedVector([1.0, 2.0]), AcceleratedVector([10.0, 20.0])),
            AcceleratedVector([11.0, 21.0, 12.0, 22.0])
        )
    }

    func testApplyAcrossFunctionVector() {
        let functions: [@Sendable (Double) -> Double] = [{ $0 + 1 }, { $0 * 2 }]
        let result = AcceleratedVector.apply(functions, AcceleratedVector([10.0, 20.0]))
        XCTAssertEqual(result, AcceleratedVector([11.0, 21.0, 20.0, 40.0]))
    }
}
