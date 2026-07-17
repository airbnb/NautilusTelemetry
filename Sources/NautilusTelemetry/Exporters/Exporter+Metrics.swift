//
//  Exporter+Metrics.swift
//
//
//  Created by Ladd Van Tol on 3/1/22.
//

import Foundation

/// Exporter utilities for Metrics models
/// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/datamodel.md
extension Exporter {

	// MARK: Public

	/// Exports an array of `Instrument` objects to OTLP format.
	/// - Parameters:
	///   - instruments: array of instruments.
	///   - additionalAttributes: Additional attributes to be added to resource attributes.
	///   - resourceAttributeOptions: Options controlling which resource attributes to include. Defaults to all except `deviceId` and `osVersion` in order to reduce metric cardinality.
	/// - Returns: JSON data.
	public func exportOTLPToJSON(
		instruments: [Instrument],
		additionalAttributes: TelemetryAttributes?,
		resourceAttributeOptions: ResourceAttributeOptions = ResourceAttributeOptions.metricSubset
	) throws -> Data {
		let metrics = exportOTLP(instruments: instruments)

		let scope = OTLP.V1InstrumentationScope(name: "NautilusTelemetry", version: "1.0")
		let resourceAttributes = ResourceAttributes.makeWithDefaults(additionalAttributes: additionalAttributes)
		let attributes = convertToOTLP(attributes: resourceAttributes.keyValues(options: resourceAttributeOptions))
		let resource = OTLP.V1Resource(attributes: attributes, droppedAttributesCount: nil)

		let scopeMetrics = OTLP.V1ScopeMetrics(scope: scope, metrics: metrics, schemaUrl: schemaUrl)
		let resourceMetrics = OTLP.V1ResourceMetrics(resource: resource, scopeMetrics: [scopeMetrics], schemaUrl: schemaUrl)
		let metricServiceRequest = OTLP.V1ExportMetricsServiceRequest(resourceMetrics: [resourceMetrics])

		return try encodeJSON(metricServiceRequest)
	}

	// MARK: Internal

	func exportOTLP(instruments: [Instrument]) -> [OTLP.V1Metric] {
		instruments.compactMap { instrument in
			if let instrument = instrument as? ExportableInstrument {
				return instrument.exportOTLP(self)
			} else {
				assertionFailure("couldn't map \(instrument)")
				return nil
			}
		}
	}

	func exportOTLP<T>(counter: Counter<T>) -> OTLP.V1Metric {
		let values = counter.values.values
		let exemplars = counter.exemplars
		var dataPoints = [OTLP.V1NumberDataPoint]()

		for key in values.keys {
			guard let value = values[key] else {
				continue
			}

			let attributes = convertToOTLP(attributes: key)
			let startTimeUnixNano = convertToOTLP(time: counter.startTime)

			let doubleValue: Double? = asDouble(value)
			let intValueString: String? = asIntString(value)

			let timeUnixNano = convertToOTLP(time: ContinuousClock.now)

			let dataPoint = OTLP.V1NumberDataPoint(
				attributes: attributes,
				startTimeUnixNano: startTimeUnixNano,
				timeUnixNano: timeUnixNano,
				asDouble: doubleValue,
				asInt: intValueString,
				exemplars: convertToOTLP(exemplars: exemplars, metricAttributes: key),
				flags: nil
			) // no flags support yet

			dataPoints.append(dataPoint)
		}

		let sum = OTLP.V1Sum(
			dataPoints: dataPoints,
			aggregationTemporality: convertToOTLP(counter.aggregationTemporality),
			isMonotonic: counter.isMonotonic
		)

		return OTLP.V1Metric(
			name: counter.name,
			description: counter.description,
			unit: convertToOTLP(counter.unit),
			gauge: nil,
			sum: sum,
			histogram: nil,
			exponentialHistogram: nil,
			summary: nil
		)
	}

	func exportOTLP<T>(counter: ObservableCounter<T>) -> OTLP.V1Metric {
		let values = counter.values.values
		let exemplars = counter.exemplars
		var dataPoints = [OTLP.V1NumberDataPoint]()

		for key in values.keys {
			guard let value = values[key] else {
				continue
			}

			let attributes = convertToOTLP(attributes: key)
			let startTimeUnixNano = convertToOTLP(time: counter.startTime)

			let doubleValue: Double? = asDouble(value)
			let intValueString: String? = asIntString(value)

			let timeUnixNano = convertToOTLP(time: ContinuousClock.now)

			let dataPoint = OTLP.V1NumberDataPoint(
				attributes: attributes,
				startTimeUnixNano: startTimeUnixNano,
				timeUnixNano: timeUnixNano,
				asDouble: doubleValue,
				asInt: intValueString,
				exemplars: convertToOTLP(exemplars: exemplars, metricAttributes: key),
				flags: nil // no flags support yet
			)

			dataPoints.append(dataPoint)
		}

		let sum = OTLP.V1Sum(
			dataPoints: dataPoints,
			aggregationTemporality: convertToOTLP(counter.aggregationTemporality),
			isMonotonic: counter.isMonotonic
		)

		return OTLP.V1Metric(
			name: counter.name,
			description: counter.description,
			unit: convertToOTLP(counter.unit),
			gauge: nil,
			sum: sum,
			histogram: nil,
			exponentialHistogram: nil,
			summary: nil
		)
	}

	func exportOTLP<T>(counter: ObservableUpDownCounter<T>) -> OTLP.V1Metric {
		let values = counter.values.values
		let exemplars = counter.exemplars
		var dataPoints = [OTLP.V1NumberDataPoint]()

		for key in values.keys {
			guard let value = values[key] else {
				continue
			}

			let attributes = convertToOTLP(attributes: key)
			let startTimeUnixNano = convertToOTLP(time: counter.startTime)

			let doubleValue: Double? = asDouble(value)
			let intValueString: String? = asIntString(value)

			let timeUnixNano = convertToOTLP(time: ContinuousClock.now)

			let dataPoint = OTLP.V1NumberDataPoint(
				attributes: attributes,
				startTimeUnixNano: startTimeUnixNano,
				timeUnixNano: timeUnixNano,
				asDouble: doubleValue,
				asInt: intValueString,
				exemplars: convertToOTLP(exemplars: exemplars, metricAttributes: key),
				flags: nil
			) // no flags support yet

			dataPoints.append(dataPoint)
		}

		let sum = OTLP.V1Sum(
			dataPoints: dataPoints,
			aggregationTemporality: convertToOTLP(counter.aggregationTemporality),
			isMonotonic: counter.isMonotonic
		)

		return OTLP.V1Metric(
			name: counter.name,
			description: counter.description,
			unit: convertToOTLP(counter.unit),
			gauge: nil,
			sum: sum,
			histogram: nil,
			exponentialHistogram: nil,
			summary: nil
		)
	}

	func exportOTLP<T>(gauge: ObservableGauge<T>) -> OTLP.V1Metric {
		let values = gauge.values.values
		let exemplars = gauge.exemplars
		var dataPoints = [OTLP.V1NumberDataPoint]()

		for key in values.keys {
			guard let value = values[key] else {
				continue
			}

			let attributes = convertToOTLP(attributes: key)
			let startTimeUnixNano = convertToOTLP(time: gauge.startTime)

			let doubleValue: Double? = asDouble(value)
			let intValueString: String? = asIntString(value)

			let timeUnixNano = convertToOTLP(time: ContinuousClock.now)

			let dataPoint = OTLP.V1NumberDataPoint(
				attributes: attributes,
				startTimeUnixNano: startTimeUnixNano,
				timeUnixNano: timeUnixNano,
				asDouble: doubleValue,
				asInt: intValueString,
				exemplars: convertToOTLP(exemplars: exemplars, metricAttributes: key),
				flags: nil
			) // no flags support yet

			dataPoints.append(dataPoint)
		}

		let gaugeOTLP = OTLP.V1Gauge(dataPoints: dataPoints)
		return OTLP.V1Metric(
			name: gauge.name,
			description: gauge.description,
			unit: convertToOTLP(gauge.unit),
			gauge: gaugeOTLP,
			sum: nil,
			histogram: nil,
			exponentialHistogram: nil,
			summary: nil
		)
	}

	func exportOTLP<T>(histogram: Histogram<T>) -> OTLP.V1Metric {
		let values = histogram.values.values
		let exemplars = histogram.exemplars
		var dataPoints = [OTLP.V1HistogramDataPoint]()

		for key in values.keys {
			guard let value = values[key] else {
				continue
			}

			let attributes = convertToOTLP(attributes: key)
			let startTimeUnixNano = convertToOTLP(time: histogram.startTime)

			let bucketCounts = convertToOTLP(bucketCounts: value.data)
			let sum = asDouble(value.sum)

			let timeUnixNano = convertToOTLP(time: histogram.endTime ?? ContinuousClock.now)

			let dataPoint = OTLP.V1HistogramDataPoint(
				attributes: attributes,
				startTimeUnixNano: startTimeUnixNano,
				timeUnixNano: timeUnixNano,
				count: "\(value.count)",
				sum: sum,
				bucketCounts: bucketCounts,
				explicitBounds: convertToOTLP(explicitBounds: value.explicitBounds),
				exemplars: convertToOTLP(exemplars: exemplars, metricAttributes: key),
				flags: nil
			)
			dataPoints.append(dataPoint)
		}

		let v1Histogram = OTLP.V1Histogram(
			dataPoints: dataPoints,
			aggregationTemporality: convertToOTLP(histogram.aggregationTemporality)
		)

		return OTLP.V1Metric(
			name: histogram.name,
			description: histogram.description,
			unit: convertToOTLP(histogram.unit),
			gauge: nil,
			sum: nil,
			histogram: v1Histogram,
			exponentialHistogram: nil,
			summary: nil
		)
	}

	func exportOTLP<T>(histogram: ExponentialHistogram<T>) -> OTLP.V1Metric {
		let values = histogram.values.values
		let exemplars = histogram.exemplars
		var dataPoints = [OTLP.V1ExponentialHistogramDataPoint]()

		for key in values.keys {
			guard let value = values[key] else {
				continue
			}

			let attributes = convertToOTLP(attributes: key)
			let startTimeUnixNano = convertToOTLP(time: histogram.startTime)
			let timeUnixNano = convertToOTLP(time: histogram.endTime ?? ContinuousClock.now)

			let doubleValues = value.recordedValues.compactMap { asDouble($0) }
			let mapped = ExponentialHistogramUtils.mapToExponentialBuckets(
				values: doubleValues,
				maxBuckets: histogram.maxBuckets
			)

			#if DEBUG
			let positiveBucketCount = mapped.positive.bucketCounts?.reduce(0, +) ?? 0
			let negativeBucketCount = mapped.negative.bucketCounts?.reduce(0, +) ?? 0
			assert(value.count == positiveBucketCount + negativeBucketCount + mapped.zeroCount)
			#endif

			let dataPoint = OTLP.V1ExponentialHistogramDataPoint(
				attributes: attributes,
				startTimeUnixNano: startTimeUnixNano,
				timeUnixNano: timeUnixNano,
				count: value.count,
				sum: asDouble(value.sum),
				scale: mapped.scale,
				zeroCount: mapped.zeroCount,
				positive: mapped.positive,
				negative: mapped.negative,
				flags: nil,
				exemplars: convertToOTLP(exemplars: exemplars, metricAttributes: key),
				min: value.range.flatMap { asDouble($0.lowerBound) },
				max: value.range.flatMap { asDouble($0.upperBound) },
				zeroThreshold: nil
			)

			dataPoints.append(dataPoint)
		}

		let v1ExponentialHistogram = OTLP.V1ExponentialHistogram(
			dataPoints: dataPoints,
			aggregationTemporality: convertToOTLP(histogram.aggregationTemporality)
		)

		return OTLP.V1Metric(
			name: histogram.name,
			description: histogram.description,
			unit: convertToOTLP(histogram.unit),
			gauge: nil,
			sum: nil,
			histogram: nil,
			exponentialHistogram: v1ExponentialHistogram,
			summary: nil
		)
	}

	/// Converts the exemplars recorded under a given data point's set of attributes to OTLP.
	/// Exemplars whose span is rejected by `exemplarSamplingDecision` are dropped, so a reporter can
	/// attach exemplars only when the linked trace is sampled.
	/// - Parameters:
	///   - exemplars: all exemplars recorded on the instrument.
	///   - metricAttributes: the attributes associated with the metric.
	/// - Returns: the matching exemplars, or `nil` if there are none.
	func convertToOTLP<T>(exemplars: [Exemplar<T>], metricAttributes: TelemetryAttributes) -> [OTLP.V1Exemplar]? {
		let matching = exemplars.filter { exemplarSamplingDecision($0.span) && $0.attributes == metricAttributes }
		guard matching.count > 0 else { return nil }

		return matching.map { exemplar in
			let span = exemplar.span
			// filtered_attributes are those recorded on the span but not already part of the data point's aggregation key.
			let extraAttributes = span.attributes?.filter { metricAttributes[$0.key] == nil } ?? [:]
			let filteredAttributes = extraAttributes.isEmpty ? nil : convertToOTLP(attributes: extraAttributes)
			let timeUnixNano = convertToOTLP(time: span.endTime ?? ContinuousClock.now)

			return OTLP.V1Exemplar(
				filteredAttributes: filteredAttributes,
				timeUnixNano: timeUnixNano,
				asDouble: asDouble(exemplar.value),
				asInt: asIntString(exemplar.value),
				spanId: span.id,
				traceId: span.traceId
			)
		}
	}

	func convertToOTLP(bucketCounts: [UInt64]) -> [String] {
		bucketCounts.map { "\($0)" }
	}

	func convertToOTLP(explicitBounds: [some MetricNumeric]) -> [Double] {
		explicitBounds.compactMap { asDouble($0) }
	}

	func convertToOTLP(_ temporality: AggregationTemporality) -> OTLP.V1AggregationTemporality {
		switch temporality {
		case .unspecified:
			.unspecified
		case .delta:
			.delta
		case .cumulative:
			.cumulative
		}
	}

	func convertToOTLP(_ unit: Unit?) -> String? {
		guard let unit else {
			return nil
		}

		// http://unitsofmeasure.org/ucum.html
		// TBD: implementation
		return unit.symbol
	}

	func asDouble(_ value: some MetricNumeric) -> Double? {
		switch value {
		case let d as Double: d
		case let i as Int: Double(i)
		default: nil
		}
	}

	/// https://opentelemetry.io/docs/specs/otlp/#json-protobuf-encoding
	/// "Note that according to Protobuf specs 64-bit integer numbers in JSON-encoded payloads are encoded as decimal strings, and either numbers or strings are accepted when decoding."
	/// For simplicity, always use string
	func asIntString(_ value: some MetricNumeric) -> String? {
		switch value {
		case let i as Int: "\(i)"
		default: nil
		}
	}
}
