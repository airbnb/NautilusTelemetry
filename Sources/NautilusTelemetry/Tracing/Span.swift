//
//  Span.swift
//
//
//  Created by Van Tol, Ladd on 9/27/21.
//

import Foundation

// MARK: - SpanKind

/// Subset of types available in OTLP.SpanSpanKind.
public enum SpanKind {
	/// Unspecified. The implementation will infer the kind from the parent span.
	case unspecified
	/// Indicates that the span represents an internal operation within an application, as opposed to an operation happening at the boundaries. This is the default.
	case `internal`
	/// Indicates that the span describes a request to some remote service.
	case client
}

// MARK: - Span

/// Implements a pared down version of the spec
/// Not thread safe -- it's assumed that Span will only be modified from a single thread.
public final class Span: Identifiable {

	// MARK: Lifecycle

	init(
		name: String,
		kind: SpanKind = .internal,
		attributes: TelemetryAttributes? = nil,
		startTime: ContinuousClock.Instant = ContinuousClock.now,
		endTime: ContinuousClock.Instant? = nil,
		traceId: TraceId,
		id: SpanId = Identifiers.generateSpanId(),
		parentId: SpanId?,
		linkedParent: Span? = nil,
		retireCallback: ((_: Span) -> Void)? = nil
	) {
		self.name = name
		self.kind = kind
		self.attributes = attributes
		self.traceId = traceId
		self.id = id
		self.parentId = parentId
		self.linkedParent = linkedParent
		self.startTime = startTime
		self.endTime = endTime
		self.retireCallback = retireCallback

		addDefaultAttributes()
	}

	// MARK: Public

	public struct Event: ExpressibleByStringLiteral {
		let time: ContinuousClock.Instant
		let name: String

		let attributes: TelemetryAttributes?

		public init(stringLiteral name: String) {
			self.init(name: name)
		}

		public init(name: String, attributes: TelemetryAttributes? = nil) {
			time = ContinuousClock.now
			self.name = name
			self.attributes = attributes
		}
	}

	public enum Status: Equatable {
		case unset
		case ok
		case error(message: String)
	}

	public let traceId: TraceId
	public let id: SpanId

	public var ended: Bool {
		endTime != nil
	}

	public func end() {
		assert(endTime == nil)
		endTime = ContinuousClock.now

		if let retireCallback {
			retireCallback(self)
			self.retireCallback = nil
		}
	}

	/// Adds an attribute to the span.
	/// - Parameters:
	///   - name: a name, conforming to https://github.com/open-telemetry/opentelemetry-specification/tree/main/specification/trace/semantic_conventions
	///   - value: a value.
	public func addAttribute(_ name: String, _ value: AnyHashable?) {
		if attributes == nil {
			attributes = TelemetryAttributes()
		}

		attributes?[name] = value
	}

	public func addEvent(_ event: Event) {
		if events == nil {
			events = [Event]()
		}
		events?.append(event)
	}

	/// "Ok represents when a developer explicitly marks a span as successful"
	/// https://opentelemetry.io/docs/concepts/signals/traces/#span-status
	public func recordSuccess() {
		status = .ok
	}

	/// Record an error into this span
	/// - Parameters:
	///   - error: any error object -- NSErrors have special handling to capture domain and code.
	///   - includeBacktrace: whether to include a backtrace. This defaults to false, and is costly at runtime.
	public func recordError(_ error: Error, includeBacktrace: Bool = false) {
		// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions/exceptions.md

		let attributes = Self.exceptionAttributes(error, includeBacktrace: includeBacktrace)
		let message = attributes["exception.message"] ?? ""
		let exceptionEvent = Event(name: "exception", attributes: attributes)
		addEvent(exceptionEvent)
		status = .error(message: message) // this duplicates exception.message, but makes the reporting work better
	}

	/// Records a result. This convenience method records either a success or an error,
	/// depending on the given result.
	/// - Parameters:
	///   - result: a result to record.
	public func record<T>(_ result: Result<T, some Error>) {
		switch result {
		case .success:
			recordSuccess()
		case .failure(let error):
			recordError(error)
		}
	}

	// MARK: Internal

	let name: String
	let kind: SpanKind
	let parentId: SpanId?
	let linkedParent: Span?
	let startTime: ContinuousClock.Instant
	var attributes: TelemetryAttributes?
	var events: [Event]? = nil // optimization -- don't generate if no events added
	var status = Status
		.unset // optimization -- we will omit status fields when unset: https://opentelemetry.io/docs/concepts/signals/traces/#span-status
	var endTime: ContinuousClock.Instant?
	var retireCallback: ((_: Span) -> Void)?

	var elapsed: Duration? {
		guard let endTime else { return nil }
		return endTime - startTime
	}

	static func exceptionAttributes(_ error: any Error, includeBacktrace: Bool) -> [String: String] {
		var attributes: [String: String]

		// All swift errors bridge to NSError, so instead check the type explicitly
		if type(of: error) is NSError.Type {
			// a "real" NSError
			let nsError = error as NSError
			let message = (error as NSError).localizedDescription
			attributes = [
				// OpenTelemetry doesn't have the concept of error codes. Pack it in exception.type.
				"exception.type": "NSError.\(nsError.domain).\(nsError.code)",
				"exception.message": message,
			]
		} else {
			let message = String(describing: error)
			attributes = [
				"exception.type": String(reflecting: type(of: error)),
				"exception.message": message,
			]
		}

		if includeBacktrace {
			// TBD: figure out proper backtracing and Swift symbol demangling?
			// This doesn't seem to exist yet: https://forums.swift.org/t/demangle-function/25416
			// This looks OK, but is ≈9K lines: https://github.com/oozoofrog/SwiftDemangle
			// Will try this, once it lands as public API:
			// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0419-backtrace-api.md
			let callStackLimit = 20
			let callstackSymbols = Thread.callStackSymbols.prefix(callStackLimit)
			let callstack = callstackSymbols.joined(separator: "\n")
			attributes["exception.stacktrace"] = callstack
		}

		// nsError.underlyingErrors contains lower-level info for network errors and may be interesting here

		return attributes
	}

	func addDefaultAttributes() {
		// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions/span-general.md#general-thread-attributes

		if Thread.isMainThread {
			addAttribute("thread.name", "main")
		} else {
			// No nice way to get the current queue, so we'll try thread name
			if let threadName = Thread.current.name, threadName.count > 0 {
				addAttribute("thread.name", threadName)
			}
		}
	}

}
