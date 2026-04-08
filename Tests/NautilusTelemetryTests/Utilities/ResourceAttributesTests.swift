//
//  ResourceAttributesTests.swift
//
//
//  Created by Van Tol, Ladd on 11/4/21.
//

import Foundation
import XCTest
@testable import NautilusTelemetry

final class ResourceAttributesTests: XCTestCase {

	func testAttributes() throws {
		let timeReference = TimeReference(serverOffset: 0.0)
		let exporter = Exporter(timeReference: timeReference)

		let attributes = ResourceAttributes.makeWithDefaults(additionalAttributes: ["foo": "bar"]).keyValues()

		_ = try XCTUnwrap(exporter.convertToOTLP(attributes: attributes)) // make sure it converts

		let serviceName = try XCTUnwrap(attributes["service.name"] as? String)
		_ = try XCTUnwrap(attributes["service.version"])
		_ = try XCTUnwrap(attributes["telemetry.sdk.name"])
		_ = try XCTUnwrap(attributes["telemetry.sdk.language"])
		_ = try XCTUnwrap(attributes["device.id"])
		_ = try XCTUnwrap(attributes["foo"])
		_ = try XCTUnwrap(attributes["os.type"])
		let osName = try XCTUnwrap(attributes["os.name"] as? String)
		let osVersion = try XCTUnwrap(attributes["os.version"] as? String)

		// Verify platform-specific OS name
		#if os(macOS)
		XCTAssertEqual(osName, "macOS")
		XCTAssertEqual(serviceName, "macos.app")
		#elseif os(iOS)
		XCTAssertEqual(osName, "iOS")
		XCTAssertEqual(serviceName, "ios.app")
		#endif

		let components = osVersion.split(separator: ".")
		XCTAssert(components.count >= 2)

		let firstComponent = try XCTUnwrap(Int(String(components[0])))

		#if os(iOS)
		XCTAssertGreaterThanOrEqual(firstComponent, 13)
		#elseif os(watchOS)
		XCTAssertGreaterThanOrEqual(firstComponent, 8)
		#else
		XCTAssertGreaterThanOrEqual(firstComponent, 11)
		#endif
	}

	func testAttributeOptionsFiltering() {
		let resourceAttributes = ResourceAttributes.makeWithDefaults(additionalAttributes: nil)

		// Test with only serviceName option
		let filtered = resourceAttributes.keyValues(options: .serviceName)
		XCTAssertNotNil(filtered["service.name"])
		XCTAssertNil(filtered["service.namespace"])
		XCTAssertNil(filtered["device.id"])
		XCTAssertNil(filtered["os.version"])

		// Test excluding deviceId and osVersion (metrics default)
		let metricsOptions: ResourceAttributeOptions = [
			.serviceName, .serviceNamespace, .serviceVersion, .telemetrySdk,
			.deviceManufacturer, .deviceModel, .osType, .osName,
		]
		let metricsFiltered = resourceAttributes.keyValues(options: metricsOptions)
		XCTAssertNotNil(metricsFiltered["service.name"])
		XCTAssertNotNil(metricsFiltered["os.name"])
		XCTAssertNil(metricsFiltered["device.id"])
		XCTAssertNil(metricsFiltered["os.version"])
	}

	func testAdditionalAttributesAlwaysIncluded() {
		let resourceAttributes = ResourceAttributes.makeWithDefaults(additionalAttributes: ["custom.key": "value"])

		// Even with empty options, additionalAttributes should be included
		let filtered = resourceAttributes.keyValues(options: [])
		XCTAssertEqual(filtered["custom.key"] as? String, "value")
		XCTAssertNil(filtered["service.name"])
	}
}
