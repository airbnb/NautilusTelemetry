// Created by Ladd Van Tol on 6/6/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

/// Extensions to be called by the application's URLSession delegate

public extension Tracer {
	
	/// Create a manually managed span to represent an URLRequest that is about to be dispatched.
	/// - Parameters:
	///   - for: the URLRequest. The `traceparent` header will be added if needed.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: A newly created span.
	func startSpan(for request: inout URLRequest, attributes: TelemetryAttributes? = nil, baggage: Baggage? = nil) -> Span {
		let name = Span.name(forRequest: request)
		let span = startSpan(name: name, kind: .client, attributes: attributes, baggage: baggage)
		span.addTraceHeadersIfSampling(&request)
		return span
	}
}
