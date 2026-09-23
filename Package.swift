// swift-tools-version: 5.9

import PackageDescription

let package = Package(
	name: "Bier",
	platforms: [.macOS(.v13)],
	products: [
		.library(name: "BierCore", targets: ["BierCore"])
	],
	targets: [
		.target(name: "BierCore"),
		.testTarget(
			name: "BierCoreTests",
			dependencies: ["BierCore"],
			path: "Tests/BierCoreTests"
		)
	]
)
