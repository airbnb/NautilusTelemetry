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

	let testMetricsWithRemoteCollector = TestUtils.testEnabled("testMetricsWithRemoteCollector")
	let testWithLocalCollector = TestUtils.testEnabled("testWithLocalCollector")
	let remoteMetricEndpointEnv = "remoteMetricEndpoint"

	let localEndpointBase = "http://localhost:4318"

	let redaction = ["startTimeUnixNano", "timeUnixNano"]
	let unit = Unit(symbol: "bytes")


	func testExportOTLPToJSON() throws {
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
			#"{"resourceMetrics":[{"resource":{"attributes":"***"},"scopeMetrics":[{"metrics":[{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":1,"dataPoints":[{"asInt":"200","attributes":"***","startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}],"scope":{"name":"NautilusTelemetry","version":"1.0"}}]}]}"#

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
			#"{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":1,"dataPoints":[{"asInt":"200","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}"#

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
			#"{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":1,"dataPoints":[{"asInt":"200","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":false},"unit":"bytes"}"#

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
			#"{"description":"Test observable Counter","name":"Test","sum":{"aggregationTemporality":1,"dataPoints":[{"asInt":"500","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}"#

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
			#"{"description":"Test observable UpDownCounter","name":"Test","sum":{"aggregationTemporality":1,"dataPoints":[{"asInt":"500","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":false},"unit":"bytes"}"#

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
			#"{"description":"Counts byte sizes by bucket","histogram":{"aggregationTemporality":1,"dataPoints":[{"attributes":[],"bucketCounts":["1","0","0","1","1"],"count":"3","explicitBounds":[1024,2048,3072,4096],"startTimeUnixNano":"***","sum":20100,"timeUnixNano":"***"}]},"name":"ByteHistogram","unit":"bytes"}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testOTLPExporterGaugeMetric() throws {
		// HOO boy: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/datamodel.md

		let timeReference = TimeReference(serverOffset: 0.0)

		var metrics = [OTLP.V1Metric]()

		var dataPoints = [OTLP.V1NumberDataPoint]()

		let now = ContinuousClock.now
		let time = timeReference.nanosecondsSinceEpoch(from: now)
		let timeString = "\(time)"

		let residentMemory = 10000 // not exposed to swift: let freeMemory = os_proc_available_memory()

		let dataPoint = OTLP.V1NumberDataPoint(
			attributes: nil,
			startTimeUnixNano: timeString,
			timeUnixNano: timeString,
			asDouble: nil,
			asInt: "\(residentMemory)",
			exemplars: nil,
			flags: nil
		)

		dataPoints.append(dataPoint)

		let gauge = OTLP.V1Gauge(dataPoints: dataPoints)
		// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/api.md#instrument-naming-rule
		// http://unitsofmeasure.org/ucum.html
		let freeMemoryMetric = OTLP.V1Metric(
			name: "resident_memory",
			description: "How many bytes of memory are resident",
			unit: "byte",
			gauge: gauge
		)

		metrics.append(freeMemoryMetric)

		let scopeMetrics = OTLP.V1ScopeMetrics(scope: TestUtils.instrumentationScope, metrics: metrics, schemaUrl: TestUtils.schemaUrl)

		let exporter = Exporter(timeReference: timeReference)

		let resource = OTLP.V1Resource(attributes: exporter.convertToOTLP(attributes: try TestUtils.additionalAttributes), droppedAttributesCount: nil)
		let resourceMetrics = OTLP.V1ResourceMetrics(resource: resource, scopeMetrics: [scopeMetrics], schemaUrl: TestUtils.schemaUrl)

		let exportMetricsServiceRequest = OTLP.V1ExportMetricsServiceRequest(resourceMetrics: [resourceMetrics])

		let json = try TestUtils.encodeJSON(exportMetricsServiceRequest)

		if testMetricsWithRemoteCollector {
			try TestUtils.postJSON(url: TestUtils.endpoint(remoteMetricEndpointEnv), json: json, test: self)
		}

		if testWithLocalCollector {
			try TestUtils.postJSON(url: try makeURL("\(localEndpointBase)/v1/metrics"), json: json, test: self)
		}
	}

	func testOTLPExporterCounterMetric() throws {
		// HOO boy: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/datamodel.md

		let timeReference = TimeReference(serverOffset: 0.0)

		var metrics = [OTLP.V1Metric]()

		var dataPoints = [OTLP.V1NumberDataPoint]()

		let now = ContinuousClock.now
		let startTime = timeReference.nanosecondsSinceEpoch(from: now)
		let endTime = startTime + 1_000_000_000

		let dataPoint = OTLP.V1NumberDataPoint(
			attributes: nil,
			startTimeUnixNano: "\(startTime)",
			timeUnixNano: "\(endTime)",
			asDouble: 200000.0,
			asInt: nil, // int doesn't seem to work
			exemplars: nil,
			flags: nil
		)

		dataPoints.append(dataPoint)

		let sum = OTLP.V1Sum(dataPoints: dataPoints, aggregationTemporality: .cumulative, isMonotonic: true)
		let testCounterMetric = OTLP.V1Metric(
			name: "test_counter",
			description: "Test counter",
			unit: nil,
			sum: sum
		)

		metrics.append(testCounterMetric)

		let scopeMetrics = OTLP.V1ScopeMetrics(scope: TestUtils.instrumentationScope, metrics: metrics, schemaUrl: TestUtils.schemaUrl)

		let exporter = Exporter(timeReference: timeReference)

		let resource = OTLP.V1Resource(attributes: exporter.convertToOTLP(attributes: try TestUtils.additionalAttributes), droppedAttributesCount: nil)
		let resourceMetrics = OTLP.V1ResourceMetrics(resource: resource, scopeMetrics: [scopeMetrics], schemaUrl: TestUtils.schemaUrl)

		let exportMetricsServiceRequest = OTLP.V1ExportMetricsServiceRequest(resourceMetrics: [resourceMetrics])

		let json = try TestUtils.encodeJSON(exportMetricsServiceRequest)

		if testMetricsWithRemoteCollector {
			try TestUtils.postJSON(url: TestUtils.endpoint(remoteMetricEndpointEnv), json: json, test: self)
		}

		if testWithLocalCollector {
			try TestUtils.postJSON(url: try makeURL("\(localEndpointBase)/v1/metrics"), json: json, test: self)
		}
	}

}
