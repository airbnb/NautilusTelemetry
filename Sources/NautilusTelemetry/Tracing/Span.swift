//
//  Span.swift
//
//
//  Created by Van Tol, Ladd on 9/27/21.
//

import Foundation
import os

// MARK: - Link

/// Minimal subset of OTLP.SpanLink with relationship concept
public struct Link {
	public enum Relationship {
		case parent
		case child
		case undefined
	}

	let traceId: TraceId
	let id: SpanId
	let relationship: Relationship
}

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
public final class Span: TelemetryAttributesContainer, Identifiable {

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
		links: [Link] = [Link](),
		retireCallback: ((_: Span) -> Void)? = nil,
		isRoot: Bool = false
	) {
		self.name = name
		self.kind = kind
		_attributes = attributes
		self.traceId = traceId
		self.id = id
		self.parentId = parentId
		self.links = links
		self.startTime = startTime
		self.endTime = endTime
		self.retireCallback = retireCallback
		self.isRoot = isRoot

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

	public let name: String
	public let traceId: TraceId
	public let id: SpanId
	public let isRoot: Bool

	public var ended: Bool {
		endTime != nil
	}

	public func end() {
		assert(endTime == nil, "span \(name) was ended more than once")
		endTime = ContinuousClock.now

		if let retireCallback {
			retireCallback(self)
			self.retireCallback = nil
		}
	}

	public func overlapsInterval(_ startInterval: ContinuousClock.Instant, endInterval: ContinuousClock.Instant) -> Bool {
		let endTime = endTime ?? .now
		return startTime <= endInterval && startInterval <= endTime
	}

	/// Adds an attribute to the span.
	/// - Parameters:
	///   - name: a name, conforming to https://github.com/open-telemetry/opentelemetry-specification/tree/main/specification/trace/semantic_conventions
	///   - value: a value.
	public func addAttribute(_ name: String, _ value: AnyHashable?) {
		guard let value else { return }

		// AnyHashable is not Sendable. For now, make this unchecked, but could consider wrapping ala:
		// https://github.com/pointfreeco/swift-concurrency-extras/blob/main/Sources/ConcurrencyExtras/AnyHashableSendable.swift
		lock.withLockUnchecked {
			if _attributes == nil {
				_attributes = TelemetryAttributes()
			}

			_attributes?[name] = value
		}
	}

	public subscript(name: String) -> AnyHashable? {
		get {
			lock.withLockUnchecked {
				_attributes?[name]
			}
		}
		set(newValue) {
			addAttribute(name, newValue)
		}
	}

	public func addEvent(_ event: Event) {
		lock.withLock {
			if events == nil {
				events = [Event]()
			}
			events?.append(event)
		}
	}

	/// link relationships are not well-defined in semantic conventions, other than OpenTracing compatibility:
	/// https://opentelemetry.io/docs/specs/semconv/registry/attributes/opentracing/
	/// In lieu of an existing standard, we'll build something reasonable
	public func addLink(_ span: Span, relationship: Link.Relationship = .undefined) {
		lock.withLock {
			links.append(Link(traceId: span.traceId, id: span.id, relationship: relationship))
		}
	}

	/// "Ok represents when a developer explicitly marks a span as successful"
	/// https://opentelemetry.io/docs/concepts/signals/traces/#span-status
	public func recordSuccess() {
		status = .ok
	}

	/// Record an error into the span.
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

	/// Record an error with a given message into the span.
	/// - Parameters:
	///   - type: a type of an error.
	///   - message: an error message to record.
	///   - includeBacktrace: whether to include a backtrace. This defaults to false, and is costly at runtime.
	public func recordError(withType type: String, message: String, includeBacktrace: Bool = false) {
		let attributes = Self.exceptionAttributes(
			type: type,
			message: message,
			stacktrace: includeBacktrace ? Self.captureStacktrace() : nil
		)

		let exceptionEvent = Event(name: "exception", attributes: attributes)
		addEvent(exceptionEvent)
		status = .error(message: message)
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

	let kind: SpanKind
	let parentId: SpanId?

	/// Span references are converted  to `Link` to avoid cyclic references.
	var links: [Link]
	let startTime: ContinuousClock.Instant
	var events: [Event]? = nil // optimization -- don't generate if no events added
	var status = Status
		.unset // optimization -- we will omit status fields when unset: https://opentelemetry.io/docs/concepts/signals/traces/#span-status
	var endTime: ContinuousClock.Instant?
	var retireCallback: ((_: Span) -> Void)?

	/// Vend private attributes as a thread-safe copy
	var attributes: TelemetryAttributes? {
		lock.withLockUnchecked { _attributes }
	}

	var elapsed: Duration? {
		guard let endTime else { return nil }
		return endTime - startTime
	}

	static func exceptionAttributes(_ error: any Error, includeBacktrace: Bool) -> [String: String] {
		let exceptionType: String
		let exceptionMessage: String

		// All swift errors bridge to NSError, so instead check the type explicitly
		if type(of: error) is NSError.Type {
			// a "real" NSError
			let nsError = error as NSError
			// OpenTelemetry doesn't have the concept of error codes. Pack it in exception.type.
			exceptionType = "NSError.\(nsError.domain).\(nsError.code)"
			exceptionMessage = (error as NSError).localizedDescription
		} else {
			exceptionType = String(reflecting: type(of: error))
			exceptionMessage = String(describing: error)
		}

		// nsError.underlyingErrors contains lower-level info for network errors and may be interesting here

		return exceptionAttributes(
			type: exceptionType,
			message: exceptionMessage,
			stacktrace: includeBacktrace ? captureStacktrace() : nil
		)
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

	// MARK: Private

	private let lock = OSAllocatedUnfairLock()

	private var _attributes: TelemetryAttributes?

	private static func exceptionAttributes(type: String, message: String, stacktrace: String?) -> [String: String] {
		var attributes = [
			"exception.type": type,
			"exception.message": message,
		]
		if let stacktrace {
			attributes["exception.stacktrace"] = stacktrace
		}

		return attributes
	}

	private static func captureStacktrace() -> String {
		// TBD: figure out proper backtracing and Swift symbol demangling?
		// This doesn't seem to exist yet: https://forums.swift.org/t/demangle-function/25416
		// This looks OK, but is ≈9K lines: https://github.com/oozoofrog/SwiftDemangle
		// Will try this, once it lands as public API:
		// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0419-backtrace-api.md
		let callStackLimit = 20
		let callstackSymbols = Thread.callStackSymbols.prefix(callStackLimit)
		return callstackSymbols.joined(separator: "\n")
	}

}
