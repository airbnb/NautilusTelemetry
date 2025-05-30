//
//  Exporter+Trace.swift
//
//
//  Created by Ladd Van Tol on 3/1/22.
//

import Foundation

/// Exporter utilities for Trace models
extension Exporter {

	// MARK: Public

	/// Exports an array of `Span` objects to OTLP format.
	/// - Parameters:
	///   - spans: array of spans.
	///   - additionalAttributes: Additional attributes to be added to resource attributes.
	/// - Returns: JSON data.
	public func exportOTLPToJSON(spans: [Span], additionalAttributes: TelemetryAttributes?) throws -> Data {
		let otlpSpans = spans.map { exportOTLP(span: $0) }

		let instrumentationScope = OTLP.V1InstrumentationScope(name: "NautilusTelemetry", version: "1.0")
		let resourceAttributes = ResourceAttributes.makeWithDefaults(additionalAttributes: additionalAttributes)
		let attributes = convertToOTLP(attributes: resourceAttributes.keyValues)
		let resource = OTLP.V1Resource(attributes: attributes, droppedAttributesCount: nil)
		let scopeSpans = OTLP.V1ScopeSpans(scope: instrumentationScope, spans: otlpSpans, schemaUrl: schemaUrl)

		let resourceSpans = OTLP.V1ResourceSpans(resource: resource, scopeSpans: [scopeSpans], schemaUrl: schemaUrl)
		let traceServiceRequest = OTLP.V1ExportTraceServiceRequest(resourceSpans: [resourceSpans])

		return try encodeJSON(traceServiceRequest)
	}

	// MARK: Internal

	/// Converts Span to OTLPv1 format Span
	/// - Parameter span: Span
	/// - Returns: Equivalent OTLP Span
	func exportOTLP(span: Span) -> OTLP.V1Span {
		let startTime = convertToOTLP(time: span.startTime)
		let endTime = convertToOTLP(time: span.endTime)

		let attributes = convertToOTLP(attributes: span.attributes)
		let events = convertToOTLP(events: span.events)
		let status = mapStatus(span.status)

		let kind = mapKind(span.kind)
		let links = buildLinks(span)

		return OTLP.V1Span(
			traceId: span.traceId,
			spanId: span.id,
			traceState: nil,
			parentSpanId: span.parentId,
			name: span.name,
			kind: kind,
			startTimeUnixNano: startTime,
			endTimeUnixNano: endTime,
			attributes: attributes,
			droppedAttributesCount: nil,
			events: events,
			droppedEventsCount: nil,
			links: links,
			droppedLinksCount: nil,
			status: status)
	}

	func mapKind(_ spanKind: SpanKind) -> OTLP.SpanSpanKind? {
		// Map the enumerate
		let otlpKind: OTLP.SpanSpanKind = switch spanKind {
		case .unspecified:
				._internal // we didn't figure it out, we'll assume internal
		case .internal:
				._internal
		case .client:
				.client
		}

		return otlpKind == ._internal ? nil : otlpKind // optimization: we can omit kind if it's internal, the default value
	}

	func mapStatus(_ spanStatus: Span.Status) -> OTLP.Tracev1Status? {
		if spanStatus == .unset {
			nil // optimization: we can omit status if it's unset, the default value
		} else {
			convertToOTLP(status: spanStatus)
		}
	}

	func buildLinks(_ span: Span) -> [OTLP.SpanLink]? {
		guard let linkedParent = span.linkedParent else { return nil }
		return [OTLP.SpanLink(traceId: linkedParent.traceId, spanId: linkedParent.id)]
	}

	/// Converts Span.Status to OTLP.V1Status
	/// - Parameter status: Span status
	/// - Returns: OTLP span status
	func convertToOTLP(status: Span.Status) -> OTLP.Tracev1Status {
		switch status {
		case .unset:
			OTLP.Tracev1Status(message: nil, code: .unset)
		case .ok:
			OTLP.Tracev1Status(message: nil, code: .ok)
		case .error(let message):
			OTLP.Tracev1Status(message: message, code: .error)
		}
	}

	/// Converts `Event` to OTLP format
	/// - Parameter events: An array of `Event` objects
	/// - Returns: events converted to OTLP format.
	func convertToOTLP(events: [Span.Event]?) -> [OTLP.SpanEvent]? {
		guard let events else {
			return nil
		}

		return events.map { event in
			let time = String(timeReference.nanosecondsSinceEpoch(from: event.time))
			let attributes = convertToOTLP(attributes: event.attributes)

			return OTLP.SpanEvent(timeUnixNano: time, name: event.name, attributes: attributes, droppedAttributesCount: nil)
		}
	}
}
