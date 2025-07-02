//
//  TraceExporterTests.swift
//
//
//  Created by Ladd Van Tol on 10/5/21.
//

import Foundation
import os
import OSLog
import XCTest

@testable import NautilusTelemetry

final class TraceExporterTests: XCTestCase {

	enum TestError: Error {
		case failure
	}

	// Since OTLP is defined in protobuf, we have to use the standard JSON mapping
	// I used `protoc-gen-swagger` for this, then a swagger -> OpenAPI 3 converter
	// Clunky, but works?
	// https://github.com/open-telemetry/opentelemetry-collector/blob/main/receiver/otlpreceiver/README.md
	// https://github.com/open-telemetry/opentelemetry-proto
	// https://developers.google.com/protocol-buffers/docs/proto3#json

	/// If you're running OpenTelemetry Collector locally, you can test out the integration:
	/// I used the Mac Docker Desktop:
	/// https://docs.docker.com/desktop/mac/install/
	/// See detailed instructions in OpenTelemetryCollector directory
	let testWithLocalCollector = TraceExporterTests.testEnabled("testWithLocalCollector")
	let testWithRemoteCollector = TraceExporterTests.testEnabled("testWithRemoteCollector")

	let instrumentationScope = OTLP.V1InstrumentationScope(name: "NautilusTelemetry", version: "1.0")
	let schemaUrl = "https://github.com/airbnb/NautilusTelemetry"

	let remoteCollectorEndpoint = "https://FILL_IN_HERE/v1/traces"
	let timeReference = TimeReference(serverOffset: 0.0)

	// Setup for a local Jaeger instance run with instructions from: https://www.jaegertracing.io/docs/2.4/getting-started/
	// docker run --rm --name jaeger \
	//  -p 16686:16686 \
	//  -p 4317:4317 \
	//  -p 4318:4318 \
	//  -p 5778:5778 \
	//  -p 9411:9411 \
	//  jaegertracing/jaeger:2.4.0

	let localEndpointBase = "http://localhost:4318"

	static func testEnabled(_ name: String) -> Bool {
		if let val = ProcessInfo.processInfo.environment[name] {
			return Bool(val) ?? false
		}
		return false
	}

	func testOTLPExporterTraces() throws {
		let tracer = Tracer()
		tracer.withSpan(name: "span1", attributes: ["small integer": 42, "large integer": 2 << 54]) {
			tracer.withSpan(name: "span2") {
				let span2 = tracer.currentBaggage.span
				span2.addEvent("event1")

				Thread.sleep(forTimeInterval: 0.05)

				try? tracer.withSpan(name: "span3") {
					Thread.sleep(forTimeInterval: 0.01)
					throw TestError.failure
				}

				tracer.withSpan(name: "span4") {
					Thread.sleep(forTimeInterval: 0.00001)
				}

				Thread.sleep(forTimeInterval: 0.05)

				span2.addEvent("event2")
				span2.recordSuccess()
			}
		}

		let spans = tracer.retiredSpans
		let exporter = Exporter(timeReference: timeReference)
		let otlpSpans = spans.map { exporter.exportOTLP(span: $0) }

		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		let data = try encoder.encode(otlpSpans)
		let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data, options: []) as? [Any])

		XCTAssertEqual(decoded.count, 4)

		let first = try XCTUnwrap(decoded[0] as? [String: Any])
		XCTAssertEqual(first["name"] as? String, "span3")

		let second = try XCTUnwrap(decoded[1] as? [String: Any])
		XCTAssertEqual(second["name"] as? String, "span4")

		let third = try XCTUnwrap(decoded[2] as? [String: Any])
		XCTAssertEqual(third["name"] as? String, "span2")

		let fourth = try XCTUnwrap(decoded[3] as? [String: Any])
		XCTAssertEqual(fourth["name"] as? String, "span1")

		let json = try exporter.exportOTLPToJSON(spans: spans, additionalAttributes: [:])

		let jsonString = try XCTUnwrap(String(data: json, encoding: .utf8))
		print(jsonString)

		if testWithRemoteCollector {
			try postJSON(url: remoteCollectorEndpoint, json: json)
		}

		if testWithLocalCollector {
			try postJSON(url: "\(localEndpointBase)/v1/traces", json: json)
		}

		tracer.flushTrace()
	}

	func testOTLPExporterLogs() throws {
		let timeReference = TimeReference(serverOffset: 0.0)
		let exporter = Exporter(timeReference: timeReference)

		let tracer = Tracer()
		tracer.withSpan(name: "hi", attributes: nil) { }

		let traceId = tracer.traceId
		let spanId = tracer.retiredSpans[0].id

		var logRecords = [OTLP.V1LogRecord]()

		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
			let logger = Logger(subsystem: "OTLPExporterTests", category: "testOTLPExporterLogs")

			for i in 0...100 {
				logger.info("Here's some sample data: \(i)")
			}

			// try dumping OS logs
			let startDate = Date().addingTimeInterval(-60)

			let logStore = try OSLogStore(scope: .currentProcessIdentifier)
			let position = logStore.position(date: startDate)
			let entries = try logStore.getEntries(at: position)

			for logEntry in entries {
				if let logEntry = logEntry as? OSLogEntryLog {
					let date = logEntry.date
					let time = timeReference.nanosecondsSinceEpoch(from: date)

					let severity = exporter.severityFrom(level: logEntry.level)
					// https://www.w3.org/TR/trace-context/#sampled-flag
					// 1 == sampled
					let flags = Int64(0x01)
					let body = logEntry.composedMessage

					let attributes: TelemetryAttributes = [
						// These don't seem to be useful yet. Can we map thread id to thread number?
						//	"activity": logEntry.activityIdentifier,
						//	"thread": logEntry.threadIdentifier,

						"category": logEntry.category,
						"process": logEntry.process,
						"sender": logEntry.sender,
						"subsystem": logEntry.subsystem,
					]

					let attributesKV = exporter.convertToOTLP(attributes: attributes)

					let logRecord = OTLP.V1LogRecord(
						timeUnixNano: "\(time)",
						severityNumber: severity,
						severityText: nil,
						body: OTLP.V1AnyValue(stringValue: body),
						attributes: attributesKV,
						droppedAttributesCount: nil,
						flags: flags,
						traceId: traceId,
						spanId: spanId
					)

					logRecords.append(logRecord)
				}
			}
		}

		let scopeLogs = OTLP.V1ScopeLogs(scope: instrumentationScope, logRecords: logRecords, schemaUrl: schemaUrl)

		let resource = OTLP.V1Resource(attributes: [], droppedAttributesCount: nil)
		let resourceLogs = OTLP.V1ResourceLogs(resource: resource, scopeLogs: [scopeLogs], schemaUrl: schemaUrl)
		let exportLogsServiceRequest = OTLP.V1ExportLogsServiceRequest(resourceLogs: [resourceLogs])

		let json = try encodeJSON(exportLogsServiceRequest)

		if testWithLocalCollector {
			try postJSON(url: "\(localEndpointBase)/v1/logs", json: json)
		}
	}

	func testSpanLink() throws {
		let traceId1 = Identifiers.generateTraceId()
		let traceId2 = Identifiers.generateTraceId()

		let span1 = Span(name: "root", traceId: traceId1, parentId: nil)
		let span2 = Span(name: "hello", traceId: traceId2, parentId: nil, linkedParent: span1)

		let exporter = Exporter(timeReference: timeReference)
		let json = try exporter.exportOTLPToJSON(spans: [span1, span2], additionalAttributes: nil)

		let normalizedJsonString = try XCTUnwrap(TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: ["startTimeUnixNano", "spanId", "traceId", "resource"]
		))
		let expectedOutput =
			#"{"resourceSpans":[{"resource":"***","scopeSpans":[{"scope":{"name":"NautilusTelemetry","version":"1.0"},"spans":[{"attributes":[{"key":"thread.name","value":{"stringValue":"main"}}],"name":"root","spanId":"***","startTimeUnixNano":"***","traceId":"***"},{"attributes":[{"key":"thread.name","value":{"stringValue":"main"}}],"links":[{"spanId":"***","traceId":"***"}],"name":"hello","spanId":"***","startTimeUnixNano":"***","traceId":"***"}]}]}]}"#

		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testSpanLinkVariant1() throws {
		let traceId1 = Identifiers.generateTraceId()
		let traceId2 = Identifiers.generateTraceId()

		// Test ok status
		let span1 = Span(name: "root", traceId: traceId1, parentId: nil)
		span1.recordSuccess()
		// Test client kind + events
		let span2 = Span(name: "hello", kind: .client, traceId: traceId2, parentId: nil, linkedParent: span1)
		span2.addEvent("OMG")

		let exporter = Exporter(timeReference: timeReference)
		let json = try exporter.exportOTLPToJSON(spans: [span1, span2], additionalAttributes: nil)

		let normalizedJsonString = try XCTUnwrap(TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: ["startTimeUnixNano", "spanId", "traceId", "resource", "timeUnixNano"]
		))

		let expectedOutput =
			#"{"resourceSpans":[{"resource":"***","scopeSpans":[{"scope":{"name":"NautilusTelemetry","version":"1.0"},"spans":[{"attributes":[{"key":"thread.name","value":{"stringValue":"main"}}],"name":"root","spanId":"***","startTimeUnixNano":"***","status":{"code":1},"traceId":"***"},{"attributes":[{"key":"thread.name","value":{"stringValue":"main"}}],"events":[{"name":"OMG","timeUnixNano":"***"}],"kind":3,"links":[{"spanId":"***","traceId":"***"}],"name":"hello","spanId":"***","startTimeUnixNano":"***","traceId":"***"}]}]}]}"#

		print(normalizedJsonString)
		XCTAssertEqual(normalizedJsonString, expectedOutput)
	}

	func testOTLPExporterMetrics() throws {
		// HOO boy: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/datamodel.md

		let tracer = Tracer()
		tracer.withSpan(name: "hi", attributes: nil) { }

		let traceId = tracer.traceId
		let spanId = tracer.retiredSpans[0].id

		let timeReference = TimeReference(serverOffset: 0.0)

		var metrics = [OTLP.V1Metric]()

		var dataPoints = [OTLP.V1NumberDataPoint]()

		let now = ContinuousClock.now
		let time = timeReference.nanosecondsSinceEpoch(from: now)
		let timeString = "\(time)"

		let residentMemory = 10000 // EBNResidentMemory() or not exposed to swift: let freeMemory = os_proc_available_memory()

		let exemplar = OTLP.V1Exemplar(
			filteredAttributes: nil,
			timeUnixNano: timeString,
			asDouble: nil,
			asInt: "\(residentMemory)",
			spanId: spanId,
			traceId: traceId
		)

		// TBD: understand all these fields, especially exemplars
		let dataPoint = OTLP.V1NumberDataPoint(
			attributes: nil,
			startTimeUnixNano: timeString,
			timeUnixNano: timeString,
			asDouble: nil,
			asInt: "\(residentMemory)",
			exemplars: [exemplar],
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

		let scopeMetrics = OTLP.V1ScopeMetrics(scope: instrumentationScope, metrics: metrics, schemaUrl: schemaUrl)
		let resource = OTLP.V1Resource(attributes: [], droppedAttributesCount: nil)
		let resourceMetrics = OTLP.V1ResourceMetrics(resource: resource, scopeMetrics: [scopeMetrics], schemaUrl: schemaUrl)

		let exportMetricsServiceRequest = OTLP.V1ExportMetricsServiceRequest(resourceMetrics: [resourceMetrics])

		let json = try encodeJSON(exportMetricsServiceRequest)

		if testWithLocalCollector {
			try postJSON(url: "\(localEndpointBase)/v1/metrics", json: json)
		}
	}

	// MARK: utilities

	func encodeJSON(_ value: some Encodable) throws -> Data {
		let encoder = JSONEncoder()
		OTLP.configure(encoder: encoder) // setup hex
		// encoder.outputFormatting = .prettyPrinted
		let json = try encoder.encode(value)

		let jsonString = try XCTUnwrap(String(data: json, encoding: .utf8))
		print("\(jsonString)")

		return json
	}

	func formattedHeaders(_ headers: [String: String]) -> String {
		var result = ""

		let keys = headers.keys.sorted()
		for key in keys {
			if let value = headers[key] {
				result.append("\(key): \(value)\n")
			}
		}

		return result
	}

	/// https://github.com/open-telemetry/opentelemetry-collector/blob/main/receiver/otlpreceiver/README.md
	func postJSON(url: String, json: Data) throws {
		let url = try strategy.parse(url)
		var urlRequest = URLRequest(url: url)

		urlRequest.httpMethod = "POST"
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
		urlRequest.setValue("\(json.count)", forHTTPHeaderField: "Content-Length")

		let compressedJSON = try Compression.compressDeflate(data: json)
		urlRequest.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
		urlRequest.httpBody = compressedJSON
		let requestHeaders = formattedHeaders(try XCTUnwrap(urlRequest.allHTTPHeaderFields))
		print("\(urlRequest.httpMethod?.description ?? "nil") \(url.path)\n\(requestHeaders)")

		let completion = expectation(description: "postToLocalOpenTelemetryCollector")
		let task = URLSession.shared.dataTask(with: urlRequest) { data, response, _ in
			if let response = response as? HTTPURLResponse {
				XCTAssertEqual(response.statusCode, 200)

				let responseHeaders = self.formattedHeaders(response.allHeaderFields as! [String: String])
				print("Response:\n\(responseHeaders)")
			}

			if let data, let jsonString = String(data: data, encoding: .utf8) {
				print("\(jsonString)")
			}

			completion.fulfill()
		}

		task.resume()

		waitForExpectations(timeout: 30) { error in
			if let error {
				print("error: \(error)")
			}
		}
	}
}
