// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AlgoLogger",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "AlgoLogger",
            targets: ["AlgoLogger"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/DaveWoodCom/XCGLogger.git", from: "7.0.1"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.0.0")),
        .package(url: "https://github.com/aws-amplify/aws-sdk-ios-spm.git", .upToNextMajor(from: "2.33.10")),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "AlgoLogger",
            dependencies: [
                "XCGLogger",
                "RxSwift",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxRelay", package: "RxSwift"),
                .product(name: "AWSCore", package: "aws-sdk-ios-spm"),
                .product(name: "AWSS3", package: "aws-sdk-ios-spm"),
                .product(name: "AWSLogs", package: "aws-sdk-ios-spm"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ]),
        .testTarget(
            name: "AlgoLoggerTests",
            dependencies: ["AlgoLogger"]),
    ]
)
