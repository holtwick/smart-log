// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SmartLog",
  products: [
    .library(
      name: "SmartLog",
      type: .dynamic,
      targets: ["SmartLog"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "SmartLog",
      dependencies: [
        .product(name: "Logging", package: "swift-log")
      ]),
    .testTarget(
      name: "SmartLogTests",
      dependencies: ["SmartLog"]),
  ]
)
