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
	/// - Returns: the created counter.
	@discardableResult
	public func reportAsCounterMetric(
		span: Span,
		namingConvention: MetricNamingConvention = .modulePrefix,
		fileID: String = #fileID
	) -> Counter<Int> {
		let name = metricName(span: span, namingConvention: namingConvention, fileID: fileID, suffix: "_counter")

		let counter = lock.withLock {
			if let counter = cachedCounters[name]?.value { return counter }
			let counter: Counter<Int> = InstrumentationSystem.meter.createCounter(
				name: name,
				unit: nil,
				description: "Created from span"
			)
			cachedCounters[name] = Weak(counter)
			return counter
		}

		span.addRetireCallback { [weak counter] _ in
			guard let counter else { return }
			counter.add(1)
		}

		return counter
	}

	/// Report span durations as an OTel ExponentialHistogram metric
	/// The histogram is strongly referenced through Meter's register, and a cached copy will be returned if the derived metric name matches.
	/// Callers need only hold a reference to the histogram if they need to later unregister.
	/// - Parameters:
	///   - span: the span to count. A metric name will be derived from the span name.
	///   - namingConvention: determines how to derive the metric name
	///   - fileID: fileID where the span was created, for module name determination.
	/// - Returns: the created histogram.
	@discardableResult
	public func reportAsDurationHistogramMetric(
		span: Span,
		namingConvention: MetricNamingConvention = .modulePrefix,
		fileID: String = #fileID
	) -> ExponentialHistogram<Int> {
		let name = metricName(span: span, namingConvention: namingConvention, fileID: fileID, suffix: "_histogram")

		let histogram = lock.withLock {
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
			histogram.record(Int(elapsed.asMilliseconds))
		}

		return histogram
	}

	// MARK: Internal

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
