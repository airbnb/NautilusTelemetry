//
//  MetricExporterTests.swift
//
//
//  Created by Ladd Van Tol on 3/2/22.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class MetricExporterTests: XCTestCase {

	let redaction = ["startTimeUnixNano", "timeUnixNano"]
	let unit = Unit(symbol: "bytes")

	func testexportOTLPToJSON() throws {
		let counter = Counter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")
		counter.add(100)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let json = try XCTUnwrap(exporter.exportOTLPToJSON(instruments: [counter], additionalAttributes: ["scenario": "test"]))

		// redact the attribute list as well
		let normalizedJsonString = try XCTUnwrap(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction + ["attributes"]
		))

		let expectedOutput =
			#"{"resourceMetrics":[{"resource":{"attributes":"***"},"scopeMetrics":[{"metrics":[{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":"AGGREGATION_TEMPORALITY_DELTA","dataPoints":[{"asInt":"200","attributes":"***","startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}],"scope":{"name":"NautilusTelemetry","version":"1.0"}}]}]}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testCounter() throws {
		let counter = Counter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")
		counter.add(100)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let metric = counter.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try XCTUnwrap(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction
		))

		let expectedOutput =
			#"{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":"AGGREGATION_TEMPORALITY_DELTA","dataPoints":[{"asInt":"200","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testUpDownCounter() throws {
		let counter = UpDownCounter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")

		counter.add(100)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try XCTUnwrap(counter.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try XCTUnwrap(TestDataNormalization.normalizedJsonString(data: json, keyValuesToRedact: redaction))

		let expectedOutput =
			#"{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":"AGGREGATION_TEMPORALITY_DELTA","dataPoints":[{"asInt":"200","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":false},"unit":"bytes"}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testObservableCounter() throws {
		let unit = Unit(symbol: "bytes")
		let counter = ObservableCounter<Int>(name: "Test", unit: unit, description: "Test observable Counter") { counter in
			counter.observe(500)
		}

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try XCTUnwrap(counter.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try TestDataNormalization.normalizedJsonString(data: json, keyValuesToRedact: redaction)

		let expectedOutput =
			#"{"description":"Test observable Counter","name":"Test","sum":{"aggregationTemporality":"AGGREGATION_TEMPORALITY_DELTA","dataPoints":[{"asInt":"500","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testObservableUpDownCounter() throws {
		let counter = ObservableUpDownCounter<Int>(name: "Test", unit: unit, description: "Test observable UpDownCounter") { counter in
			counter.observe(500)
		}

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try XCTUnwrap(counter.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try TestDataNormalization.normalizedJsonString(data: json, keyValuesToRedact: redaction)

		let expectedOutput =
			#"{"description":"Test observable UpDownCounter","name":"Test","sum":{"aggregationTemporality":"AGGREGATION_TEMPORALITY_DELTA","dataPoints":[{"asInt":"500","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":false},"unit":"bytes"}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testObservableGauge() throws {
		let gauge = ObservableGauge<Int>(name: "Test", unit: unit, description: "Test observable gauge") { gauge in
			gauge.observe(500)
		}

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try XCTUnwrap(gauge.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try TestDataNormalization.normalizedJsonString(data: json, keyValuesToRedact: redaction)

		let expectedOutput =
			#"{"description":"Test observable gauge","gauge":{"dataPoints":[{"asInt":"500","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}]},"name":"Test","unit":"bytes"}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testHistogram() throws {
		let bucketSize = 1024

		let histogram = Histogram<Int>(
			name: "ByteHistogram",
			unit: unit,
			description: "Counts byte sizes by bucket",
			explicitBounds: [bucketSize * 1, bucketSize * 2, bucketSize * 3, bucketSize * 4]
		)

		histogram.record(100)
		histogram.record(4000)
		histogram.record(16000)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try XCTUnwrap(histogram.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try TestDataNormalization.normalizedJsonString(data: json, keyValuesToRedact: redaction)

		let expectedOutput =
			#"{"description":"Counts byte sizes by bucket","histogram":{"aggregationTemporality":"AGGREGATION_TEMPORALITY_DELTA","dataPoints":[{"attributes":[],"bucketCounts":["1","0","0","1","1"],"count":"3","explicitBounds":[1024,2048,3072,4096],"startTimeUnixNano":"***","sum":20100,"timeUnixNano":"***"}]},"name":"ByteHistogram","unit":"bytes"}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

}
