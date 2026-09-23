// swift-tools-version: 5.9

import PackageDescription

let package = Package(
	name: "Bier",
	platforms: [.macOS(.v13)],
	products: [
		.library(name: "BierCore", targets: ["BierCore"]),
		.executable(name: "bier-agent", targets: ["BierAgent"]),
		.executable(name: "bier-peer", targets: ["BierPeer"])
	],
	targets: [
		.target(name: "BierCore", path: "Sources/bier-core/swift"),
		.executableTarget(
			name: "BierAgent",
			dependencies: ["BierCore"],
			path: "Sources/bier-agent",
			exclude: [
				"PEER-DATA-PROTOCOL.md",
				"README.md",
				"build.sh"
			],
			sources: ["BierAgent.swift"],
			swiftSettings: [.define("BIER_PACKAGE")]
		),
		.executableTarget(name: "BierPeer", dependencies: ["BierCore"], path: "Sources/bier-peer", exclude: ["build.sh"]),
		.testTarget(
			name: "BierCoreTests",
			dependencies: ["BierCore"],
			path: "Tests/BierCoreTests"
		)
	]
)
