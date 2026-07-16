// Created by Ladd Van Tol on 4/21/26.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import Foundation

extension Tracer {

	// MARK: Public

	public enum MetricNamingConvention {
		/// Use format MODULE_name_METRICTYPE
		case modulePrefix
		/// Use format name_METRICTYPE
		case raw
	}

	/// Report span counts as an OTel Counter metric
	/// The counter is strongly referenced through Meter's register, and a cached copy will be returned if the derived metric name matches.
	/// Callers need only hold a reference to the counter if they need to later unregister.
	/// - Parameters:
	///   - span: the span to count. A metric name will be derived from the span name.
	///   - namingConvention: determines how to derive the metric name
	///   - fileID: fileID where the span was created, for module name determination.
	///   - spanAttributeKeys: A set of attribute keys to collect from the span when it is ended. This set should be minimal to avoid metric cardinality explosion.
	/// - Returns: the created counter.
	@discardableResult
	public func reportAsCounterMetric(
		span: Span,
		namingConvention: MetricNamingConvention = .modulePrefix,
		fileID: String = #fileID,
		spanAttributeKeys: Set<String>? = nil
	) -> Counter<Int> {
		let name = metricName(span: span, namingConvention: namingConvention, fileID: fileID, suffix: "_counter")

		let counter = lock.withLock { _ in
			if let counter = cachedCounters[name]?.value { return counter }
			let counter: Counter<Int> = InstrumentationSystem.meter.createCounter(
				name: name,
				unit: nil,
				description: "Created from span"
			)
			cachedCounters[name] = Weak(counter)
			return counter
		}

		span.addRetireCallback { [weak counter] span in
			guard let counter else { return }
			let attributes = Self.collectAttributes(span, spanAttributeKeys)
			counter.add(1, attributes: attributes)
			counter.addExemplar(span: span, value: 1, attributes: attributes)
		}

		return counter
	}

	/// Report span durations as an OTel ExponentialHistogram metric
	/// The histogram is strongly referenced through Meter's register, and a cached copy will be returned if the derived metric name matches.
	/// Callers need only hold a reference to the histogram if they need to later unregister.
	/// - Parameters:
	///   - span: the span to measure. A metric name will be derived from the span name.
	///   - namingConvention: determines how to derive the metric name
	///   - fileID: fileID where the span was created, for module name determination.
	///   - spanAttributeKeys: A set of attribute keys to collect from the span when it is ended. This set should be minimal to avoid metric cardinality explosion.
	/// - Returns: the created histogram.
	@discardableResult
	public func reportAsDurationHistogramMetric(
		span: Span,
		namingConvention: MetricNamingConvention = .modulePrefix,
		fileID: String = #fileID,
		spanAttributeKeys: Set<String>? = nil
	) -> ExponentialHistogram<Int> {
		let name = metricName(span: span, namingConvention: namingConvention, fileID: fileID, suffix: "_histogram")

		let histogram = lock.withLock { _ in
			if let histogram = cachedDurationHistograms[name]?.value { return histogram }
			let histogram: ExponentialHistogram<Int> = InstrumentationSystem.meter.createExponentialHistogram(
				name: name,
				unit: Unit(symbol: "ms"),
				description: "Created from span"
			)
			cachedDurationHistograms[name] = Weak(histogram)
			return histogram
		}

		span.addRetireCallback { [weak histogram] span in
			guard let histogram, let elapsed = span.elapsed else { return }
			let value = Int(elapsed.asMilliseconds)
			let attributes = Self.collectAttributes(span, spanAttributeKeys)
			histogram.record(value, attributes: attributes)
			histogram.addExemplar(span: span, value: value, attributes: attributes)
		}

		return histogram
	}

	// MARK: Internal

	/// Collect a set of named span attributes
	/// - Parameters:
	///   - span: The span
	///   - spanAttributeKeys: The names of attributes to collect
	/// - Returns: The matching attributes, or an empty dictionary if no keys were requested or none matched.
	static func collectAttributes(_ span: Span, _ spanAttributeKeys: Set<String>?) -> TelemetryAttributes {
		guard let spanAttributeKeys, !spanAttributeKeys.isEmpty else { return [:] }
		return span.attributes?.filter { spanAttributeKeys.contains($0.key) } ?? [:]
	}

	func metricName(span: Span, namingConvention: MetricNamingConvention, fileID: String = #fileID, suffix: String) -> String {
		switch namingConvention {
		case .modulePrefix:
			// Would like to have #module to avoid parsing cost. Alas!
			let moduleName = String(fileID.prefix(while: { $0 != "/" }))
			return moduleName + "_" + span.name + suffix

		case .raw:
			return span.name + suffix
		}
	}
}
