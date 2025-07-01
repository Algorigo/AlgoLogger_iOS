// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AlgoLogger",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name:"AlgoLoggerCommon",
            targets: ["AlgoLoggerCommon"]),
        .library(
            name: "AlgoLogger",
            targets: ["AlgoLogger"]),
        .library(
            name: "AlgoLoggerAWS",
            targets: ["AlgoLoggerAWS"]),
        .library(
            name: "AlgoLoggerDatadog",
            targets: ["AlgoLoggerDatadog"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/DaveWoodCom/XCGLogger.git", from: "7.1.5"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.9.0")),
        .package(url: "https://github.com/aws-amplify/aws-sdk-ios-spm.git", .upToNextMajor(from: "2.36.0")),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", .upToNextMajor(from: "0.13.0")),
        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", exact: "2.25.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AlgoLoggerCommon",
            path: "AlgoLoggerCommon"),
        .target(
            name: "AlgoLogger",
            dependencies: [
                "AlgoLoggerCommon",
                "XCGLogger",
                "RxSwift",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxRelay", package: "RxSwift"),
            ],
            path: "AlgoLogger"),
        .target(
            name: "AlgoLoggerAWS",
            dependencies: [
                "AlgoLogger",
                "XCGLogger",
                "RxSwift",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxRelay", package: "RxSwift"),
                .product(name: "AWSCore", package: "aws-sdk-ios-spm"),
                .product(name: "AWSS3", package: "aws-sdk-ios-spm"),
                .product(name: "AWSLogs", package: "aws-sdk-ios-spm"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "AlgoLoggerAWS"),
        .target(
            name: "AlgoLoggerDatadog",
            dependencies: [
                "AlgoLoggerCommon",
                "XCGLogger",
                .product(name: "DatadogCore", package: "dd-sdk-ios"),
                .product(name: "DatadogLogs", package: "dd-sdk-ios"),
            ],
            path: "AlgoLoggerDatadog"),
    ]
)
