// swift-tools-version: 6.3

import PackageDescription

let customOperator: [Target] = [
    .target(
        name: "MathOperators",
        dependencies: [
            "Math",
            .product(name: "CoreFPOperators", package: "FP")
        ]
    )
]

let calculus: [Target] = [
    .target(name: "RungeKutta", dependencies: ["Calculus"]),
    .target(
        name: "Calculus",
        dependencies: [
            "Math",
            .product(name: "CoreFP", package: "FP")
        ]
    ),
    .target(
        name: "Math",
        dependencies: [
            "RealNumber",
            .product(name: "CoreFP", package: "FP")
        ]
    ),
    .target(name: "RealNumber")
]

let package = Package(
    name: "SwiftCalx",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "Math", targets: ["Math", "MathOperators"]),
        .library(name: "MathNoOperators", targets: ["Math"]),
        .library(name: "Calculus", targets: ["Calculus", "MathOperators"]),
        .library(name: "CalculusNoOperators", targets: ["Calculus"]),
        .library(name: "RungeKutta", targets: ["RungeKutta", "MathOperators"]),
        .library(name: "SwiftCalx", targets: ["SwiftCalx"])
    ],
    dependencies: [
        .package(url: "https://github.com/luizmb/FP.git", from: "1.14.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0")
    ],
    targets: customOperator + calculus + [
        .target(name: "SwiftCalx", dependencies: ["RungeKutta", "MathOperators"]),
        .testTarget(name: "CalculusTests", dependencies: ["Calculus", "MathOperators"]),
        .testTarget(name: "MathOperatorsTests", dependencies: ["MathOperators"]),
        .testTarget(name: "MathTests", dependencies: ["Math", "MathOperators"]),
        .testTarget(name: "RealNumberTests", dependencies: ["RealNumber"]),
        .testTarget(name: "RungeKuttaTests", dependencies: ["RungeKutta"])
    ]
)
