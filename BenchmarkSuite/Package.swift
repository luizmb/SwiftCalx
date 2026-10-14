// swift-tools-version: 6.2
import PackageDescription

// Benchmarks live in a nested package so the published SwiftCalx library never gains a
// dependency on package-benchmark (or its jemalloc system requirement). It references the
// root package by path and is built/run only on demand.
let package = Package(
    name: "SwiftCalxBenchmarks",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.4.0")
    ],
    targets: [
        .executableTarget(
            name: "CalxBenchmarks",
            dependencies: [
                .product(name: "Math", package: "SwiftCalx"),
                .product(name: "Calculus", package: "SwiftCalx"),
                .product(name: "RungeKutta", package: "SwiftCalx"),
                .product(name: "Benchmark", package: "benchmark")
            ],
            path: "Benchmarks/CalxBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        )
    ]
)
