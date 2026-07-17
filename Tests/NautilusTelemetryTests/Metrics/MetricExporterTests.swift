//
//  MetricExporterTests.swift
//
//
//  Created by Ladd Van Tol on 3/2/22.
//

import Foundation
import Testing

@testable import NautilusTelemetry

@Suite
struct MetricExporterTests {

	let testWithRemoteCollector = TestUtils.testEnabled("testMetricsWithRemoteCollector")
	let testWithLocalCollector = TestUtils.testEnabled("testWithLocalCollector")
	let remoteMetricEndpointEnv = "remoteMetricEndpoint"

	let localEndpointBase = "http://localhost:4318"

	let redaction = ["startTimeUnixNano", "timeUnixNano"]
	let unit = Unit(symbol: "bytes")

	@Test
	func exportOTLPToJSON() throws {
		let counter = Counter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")
		counter.add(100)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let json = try exporter.exportOTLPToJSON(instruments: [counter], additionalAttributes: ["scenario": "test"])

		// redact the attribute list as well
		let normalizedJsonString = try #require(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction + ["attributes"]
		))

		let expectedOutput =
			#"{"resourceMetrics":[{"resource":{"attributes":"***"},"scopeMetrics":[{"metrics":[{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":1,"dataPoints":[{"asDouble":100,"asInt":"100","attributes":"***","startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}],"scope":{"name":"NautilusTelemetry","version":"1.0"}}]}]}"#

		#expect(normalizedJsonString == expectedOutput)
	}

	@Test
	func counter() throws {
		let counter = Counter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")
		counter.add(100)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let metric = counter.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try #require(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction
		))

		let expectedOutput =
			#"{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":1,"dataPoints":[{"asDouble":100,"asInt":"100","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}"#

		#expect(normalizedJsonString == expectedOutput)
	}

	@Test
	func counterExemplars() throws {
		let counter = Counter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")

		let span = InstrumentationSystem.tracer.startSpan(name: "exemplarSpan")
		span.addAttribute("http.target", "/checkout")
		span.end()

		let attributes: TelemetryAttributes = ["route": "home"]
		counter.add(1, attributes: attributes)
		counter.addExemplar(span: span, value: 1, attributes: attributes)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let metric = counter.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		// spanId/traceId/filteredAttributes vary per run, so redact them along with the timestamps.
		let normalizedJsonString = try #require(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction + ["attributes", "filteredAttributes", "spanId", "traceId"]
		))

		let expectedOutput =
			#"{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":1,"dataPoints":[{"asDouble":1,"asInt":"1","attributes":"***","exemplars":[{"asDouble":1,"asInt":"1","filteredAttributes":"***","spanId":"***","timeUnixNano":"***","traceId":"***"}],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}"#

		#expect(normalizedJsonString == expectedOutput)
	}

	@Test
	func exemplarSnapshotAndReset() throws {
		let counter = Counter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")

		let span = InstrumentationSystem.tracer.startSpan(name: "exemplarSpan")
		span.end()

		counter.add(1)
		counter.addExemplar(span: span, value: 1)

		#expect(counter.exemplarSpans.count == 1)

		let snapshot = try #require(counter.snapshotAndReset() as? Counter<Int>)

		// Exemplars move to the snapshot; the live instrument is reset.
		#expect(snapshot.exemplarSpans.map(\.id) == [span.id])
		#expect(counter.exemplarSpans.isEmpty)
	}

	@Test
	func exemplarsMatchDataPointAttributes() throws {
		let counter = Counter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")

		let homeSpan = InstrumentationSystem.tracer.startSpan(name: "home")
		homeSpan.end()
		let cartSpan = InstrumentationSystem.tracer.startSpan(name: "cart")
		cartSpan.end()

		let home: TelemetryAttributes = ["route": "home"]
		let cart: TelemetryAttributes = ["route": "cart"]

		counter.addExemplar(span: homeSpan, value: 1, attributes: home)
		counter.addExemplar(span: cartSpan, value: 1, attributes: cart)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		// Exemplars only attach to the data point sharing their aggregation key.
		let homeExemplars = try #require(exporter.convertToOTLP(exemplars: counter.exemplars, metricAttributes: home))
		#expect(homeExemplars.map(\.spanId) == [homeSpan.id])

		let cartExemplars = try #require(exporter.convertToOTLP(exemplars: counter.exemplars, metricAttributes: cart))
		#expect(cartExemplars.map(\.spanId) == [cartSpan.id])

		#expect(exporter.convertToOTLP(exemplars: counter.exemplars, metricAttributes: ["route": "search"]) == nil)
	}

	@Test
	func exemplarSamplingDecision() throws {
		let counter = Counter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")

		let sampledSpan = InstrumentationSystem.tracer.startSpan(name: "sampled")
		sampledSpan.end()
		let unsampledSpan = InstrumentationSystem.tracer.startSpan(name: "unsampled")
		unsampledSpan.end()

		counter.addExemplar(span: sampledSpan, value: 1)
		counter.addExemplar(span: unsampledSpan, value: 1)

		let timeReference = TimeReference(serverOffset: 0)

		// Decision drops everything: no exemplars are attached.
		let noneExporter = Exporter(timeReference: timeReference, exemplarSamplingDecision: { _ in false })
		#expect(noneExporter.convertToOTLP(exemplars: counter.exemplars, metricAttributes: [:]) == nil)

		// Decision keeps only the sampled span.
		let selectiveExporter = Exporter(timeReference: timeReference, exemplarSamplingDecision: { $0.id == sampledSpan.id })
		let attached = try #require(selectiveExporter.convertToOTLP(exemplars: counter.exemplars, metricAttributes: [:]))
		#expect(attached.map(\.spanId) == [sampledSpan.id])

		// Default decision attaches every exemplar.
		let defaultExporter = Exporter(timeReference: timeReference)
		#expect(defaultExporter.convertToOTLP(exemplars: counter.exemplars, metricAttributes: [:])?.count == 2)
	}

	@Test
	func upDownCounter() throws {
		let counter = UpDownCounter<Int>(name: "ByteCounter", unit: unit, description: "Counts accumulated bytes")

		counter.add(100)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try #require(counter.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try #require(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction
		))

		let expectedOutput =
			#"{"description":"Counts accumulated bytes","name":"ByteCounter","sum":{"aggregationTemporality":1,"dataPoints":[{"asDouble":100,"asInt":"100","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":false},"unit":"bytes"}"#

		#expect(normalizedJsonString == expectedOutput)
	}

	@Test
	func observableCounter() throws {
		let unit = Unit(symbol: "bytes")
		let counter = ObservableCounter<Int>(name: "Test", unit: unit, description: "Test observable Counter") { counter in
			counter.observe(500)
		}

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try #require(counter.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try #require(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction
		))

		let expectedOutput =
			#"{"description":"Test observable Counter","name":"Test","sum":{"aggregationTemporality":1,"dataPoints":[{"asDouble":500,"asInt":"500","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":true},"unit":"bytes"}"#

		#expect(normalizedJsonString == expectedOutput)
	}

	@Test
	func observableUpDownCounter() throws {
		let counter = ObservableUpDownCounter<Int>(name: "Test", unit: unit, description: "Test observable UpDownCounter") { counter in
			counter.observe(500)
		}

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try #require(counter.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try #require(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction
		))

		let expectedOutput =
			#"{"description":"Test observable UpDownCounter","name":"Test","sum":{"aggregationTemporality":1,"dataPoints":[{"asDouble":500,"asInt":"500","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}],"isMonotonic":false},"unit":"bytes"}"#

		#expect(normalizedJsonString == expectedOutput)
	}

	@Test
	func observableGauge() throws {
		let gauge = ObservableGauge<Int>(name: "Test", unit: unit, description: "Test observable gauge") { gauge in
			gauge.observe(500)
		}

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let exportableInstrument = try #require(gauge.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try #require(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction
		))

		let expectedOutput =
			#"{"description":"Test observable gauge","gauge":{"dataPoints":[{"asDouble":500,"asInt":"500","attributes":[],"startTimeUnixNano":"***","timeUnixNano":"***"}]},"name":"Test","unit":"bytes"}"#

		#expect(normalizedJsonString == expectedOutput)
	}

	@Test
	func histogram() throws {
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

		let exportableInstrument = try #require(histogram.snapshotAndReset() as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)

		let normalizedJsonString = try #require(try TestDataNormalization.normalizedJsonString(
			data: json,
			keyValuesToRedact: redaction
		))

		let expectedOutput =
			#"{"description":"Counts byte sizes by bucket","histogram":{"aggregationTemporality":1,"dataPoints":[{"attributes":[],"bucketCounts":["1","0","0","1","1"],"count":"3","explicitBounds":[1024,2048,3072,4096],"startTimeUnixNano":"***","sum":20100,"timeUnixNano":"***"}]},"name":"ByteHistogram","unit":"bytes"}"#

		#expect(normalizedJsonString == expectedOutput)
	}

	@Test
	func exponentialHistogram() async throws {
		let msUnit = Unit(symbol: "ms")
		let histogram = ExponentialHistogram<Double>(
			name: "LatencyHistogram",
			unit: msUnit,
			description: "Request latency sampled from a normal distribution"
		)

		// Normal distribution via Box-Muller
		let mode = Bool.random()
		let maxValue = 100000.0
		let mean = mode ? 150.0 : 300.0 // Fake bimodal distribution
		let stdDev = 50.0
		let sampleCount = 1000

		var samples = [Double]()
		samples.reserveCapacity(sampleCount)
		for _ in 0..<sampleCount {
			let u1 = max(Double.leastNormalMagnitude, Double.random(in: 0.0..<1.0))
			let u2 = Double.random(in: 0.0..<1.0)
			let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
			let value = max(0.0, min(maxValue, mean + stdDev * z))
			samples.append(value)
			histogram.record(value)
		}

		// Make end time differ
		try await Task.sleep(for: .milliseconds(100))

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let snapshot = histogram.snapshotAndReset()
		let exportableInstrument = try #require(snapshot as? ExportableInstrument)
		let metric = exportableInstrument.exportOTLP(exporter)

		#expect(metric.name == "LatencyHistogram")
		#expect(metric.unit == "ms")
		#expect(metric.histogram == nil)

		let expHist = try #require(metric.exponentialHistogram)
		#expect(expHist.aggregationTemporality == .delta)

		let dp = try #require(expHist.dataPoints?.first)
		#expect(dp.count == UInt64(sampleCount))

		let expectedSum = samples.reduce(0.0, +)
		let sum = try #require(dp.sum)
		#expect(abs(sum - expectedSum) < 1e-6)
		#expect(dp.min == samples.min())
		#expect(dp.max == samples.max())

		let zeroCount = dp.zeroCount ?? 0
		let positiveCount = dp.positive?.bucketCounts?.reduce(0, +) ?? 0
		let negativeCount = dp.negative?.bucketCounts?.reduce(0, +) ?? 0
		#expect(positiveCount + negativeCount + zeroCount == UInt64(sampleCount))

		// Clamped to [0, 100] so there should be no negative buckets.
		#expect(negativeCount == 0)

		// Buckets must stay within the configured window.
		let positiveBuckets = try #require(dp.positive?.bucketCounts)
		#expect(positiveBuckets.count <= histogram.maxBuckets)

		// The chosen scale should be within the spec range.
		let scale = try #require(dp.scale)
		#expect(scale >= ExponentialHistogramUtils.minScale)
		#expect(scale <= ExponentialHistogramUtils.maxScale)

		// JSON should encode successfully and include the exponentialHistogram payload.
		let json = try exporter.encodeJSON(metric)
		let jsonString = try #require(String(data: json, encoding: .utf8))
		#expect(jsonString.contains("\"exponentialHistogram\""))
		#expect(jsonString.contains("\"unit\":\"ms\""))

		guard testWithLocalCollector || testWithRemoteCollector else { return }

		// If the collector requires tenant ID or other metadata, can be configured here.
		let additionalAttributes = try TestUtils.additionalAttributes

		let requestJSON = try exporter.exportOTLPToJSON(instruments: [snapshot], additionalAttributes: additionalAttributes)

		if testWithRemoteCollector {
			try await TestUtils.postJSON(url: TestUtils.endpoint(remoteMetricEndpointEnv), json: requestJSON)
		}

		if testWithLocalCollector {
			try await TestUtils.postJSON(url: TestUtils.makeURL("\(localEndpointBase)/v1/metrics"), json: requestJSON)
		}
	}

	@Test
	func tracerMetrics() async throws {
		let tracer = InstrumentationSystem.tracer
		let timingRange = 0...1.0

		let span = tracer.startSpan(name: "testSpan")
		let counter = tracer.reportAsCounterMetric(span: span)
		let histogram = tracer.reportAsDurationHistogramMetric(span: span)

		// Use the adjustment API so we don't have to actually wait
		span.adjust(start: .zero, end: Duration.seconds(Double.random(in: timingRange)))

		span.end()

		for _ in 0..<1000 {
			let span = tracer.startSpan(name: "testSpan")
			let counter2 = tracer.reportAsCounterMetric(span: span)
			#expect(counter === counter2)
			let histogram2 = tracer.reportAsDurationHistogramMetric(span: span)
			#expect(histogram === histogram2)
			span.adjust(start: .zero, end: Duration.seconds(Double.random(in: timingRange)))
			span.end()
		}

		// If the collector requires tenant ID or other metadata, can be configured here.
		let additionalAttributes = try TestUtils.additionalAttributes

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let requestJSON = try exporter.exportOTLPToJSON(instruments: [counter, histogram], additionalAttributes: additionalAttributes)

		if testWithRemoteCollector {
			try await TestUtils.postJSON(url: TestUtils.endpoint(remoteMetricEndpointEnv), json: requestJSON)
		}

		if testWithLocalCollector {
			try await TestUtils.postJSON(url: TestUtils.makeURL("\(localEndpointBase)/v1/metrics"), json: requestJSON)
		}
	}

	@Test
	func otlpExporterGaugeMetric() async throws {
		guard testWithLocalCollector || testWithRemoteCollector else { return }

		let timeReference = TimeReference(serverOffset: 0.0)

		var metrics = [OTLP.V1Metric]()

		var dataPoints = [OTLP.V1NumberDataPoint]()

		let now = ContinuousClock.now
		let time = timeReference.nanosecondsSinceEpoch(from: now)
		let timeString = "\(time)"

		let residentMemory = 20000 // not exposed to swift: let freeMemory = os_proc_available_memory()

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

		let resource = OTLP.V1Resource(
			attributes: exporter.convertToOTLP(attributes: try TestUtils.additionalAttributes),
			droppedAttributesCount: nil
		)
		let resourceMetrics = OTLP.V1ResourceMetrics(resource: resource, scopeMetrics: [scopeMetrics], schemaUrl: TestUtils.schemaUrl)

		let exportMetricsServiceRequest = OTLP.V1ExportMetricsServiceRequest(resourceMetrics: [resourceMetrics])

		let json = try TestUtils.encodeJSON(exportMetricsServiceRequest)

		if testWithRemoteCollector {
			try await TestUtils.postJSON(url: TestUtils.endpoint(remoteMetricEndpointEnv), json: json)
		}

		if testWithLocalCollector {
			try await TestUtils.postJSON(url: TestUtils.makeURL("\(localEndpointBase)/v1/metrics"), json: json)
		}
	}

	@Test
	func otlpExporterCounterMetric() async throws {
		guard testWithLocalCollector || testWithRemoteCollector else { return }

		let timeReference = TimeReference(serverOffset: 0.0)

		var metrics = [OTLP.V1Metric]()

		var dataPoints = [OTLP.V1NumberDataPoint]()

		let now = ContinuousClock.now
		let startTime = timeReference.nanosecondsSinceEpoch(from: now)
		let endTime = startTime + 1_000_000_000

		let exporter = Exporter(timeReference: timeReference)

		let dataPoint = OTLP.V1NumberDataPoint(
			attributes: exporter.convertToOTLP(attributes: ["test": "1"]),
			startTimeUnixNano: "\(startTime)",
			timeUnixNano: "\(endTime)",
			asDouble: 8880.0,
			asInt: "8880", // int doesn't seem to work
			exemplars: nil,
			flags: nil
		)

		dataPoints.append(dataPoint)

		let sum = OTLP.V1Sum(dataPoints: dataPoints, aggregationTemporality: .cumulative, isMonotonic: true)
		let testCounterMetric = OTLP.V1Metric(
			name: "lychee_counter",
			description: "Test counter",
			unit: nil,
			sum: sum
		)

		metrics.append(testCounterMetric)

		let scopeMetrics = OTLP.V1ScopeMetrics(scope: TestUtils.instrumentationScope, metrics: metrics, schemaUrl: TestUtils.schemaUrl)

		let resource = OTLP.V1Resource(
			attributes: exporter.convertToOTLP(attributes: try TestUtils.additionalAttributes),
			droppedAttributesCount: nil
		)
		let resourceMetrics = OTLP.V1ResourceMetrics(resource: resource, scopeMetrics: [scopeMetrics], schemaUrl: TestUtils.schemaUrl)

		let exportMetricsServiceRequest = OTLP.V1ExportMetricsServiceRequest(resourceMetrics: [resourceMetrics])

		let json = try TestUtils.encodeJSON(exportMetricsServiceRequest)

		if testWithRemoteCollector {
			try await TestUtils.postJSON(url: TestUtils.endpoint(remoteMetricEndpointEnv), json: json)
		}

		if testWithLocalCollector {
			try await TestUtils.postJSON(url: TestUtils.makeURL("\(localEndpointBase)/v1/metrics"), json: json)
		}
	}

}
