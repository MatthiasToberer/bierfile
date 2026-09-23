// swift-tools-version: 5.9

import PackageDescription

let package = Package(
	name: "Bier",
	platforms: [.macOS(.v13)],
	products: [
		.library(name: "BierCore", targets: ["BierCore"])
	],
	targets: [
		.target(
			name: "BierCore",
			path: "agent",
			exclude: [
				"BierAgent.swift",
				"PEER-DATA-PROTOCOL.md",
				"README.md",
				"SnapshotTest.swift",
				"build.sh",
				"test.sh"
			],
			sources: ["DataManifest.swift", "DataSnapshot.swift"]
		),
		.testTarget(
			name: "BierCoreTests",
			dependencies: ["BierCore"],
			path: "Tests/BierCoreTests"
		)
	]
)
