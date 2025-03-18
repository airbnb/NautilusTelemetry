// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Copyright © 2021 eBay. All rights reserved.

import PackageDescription

let package = Package(
	name: "NautilusTelemetry",
	platforms: [.iOS("16.0"), .tvOS("16.0"), .macOS("13.0"), .watchOS("9.0")],
	products: [
		// Products define the executables and libraries a package produces, and make them visible to other packages.
		.library(
			name: "NautilusTelemetry",
			type: .static,
			targets: ["NautilusTelemetry"]),
		.library(
			name: "SampleCode",
			type: .static,
			targets: ["SampleCode"])
	],
	dependencies: [
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages this package depends on.
		.target(
			name: "NautilusTelemetry",
			dependencies: [],
			exclude: [
				"Exporters/OTLP-JSON/openapi-generator",
				"Exporters/OTLP-JSON/Metrics/metrics_service.yaml",
				"Exporters/OTLP-JSON/Trace/trace_service.yaml",
				"Exporters/OTLP-JSON/Logs/logs_service.yaml",
				"Instrumentation/MetricKit-sample.json"
			]),
		.testTarget(
			name: "NautilusTelemetryTests",
			dependencies: ["NautilusTelemetry"]),
		.target(
			name: "SampleCode",
			dependencies: ["NautilusTelemetry"]),
	]
)
