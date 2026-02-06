//
//  Tracer.swift
//
//
//  Created by Van Tol, Ladd on 10/4/21.
//

import Foundation
import os

public final class Tracer {

	// MARK: Lifecycle

	public init() {
		flushInterval = Self.defaultFlushInterval
		idleTimeoutInterval = Self.defaultIdleInterval
		flushTimer = FlushTimer(flushInterval: flushInterval, repeating: true) { [weak self] in self?.flushRetiredSpans() }
		idleTimer = FlushTimer(flushInterval: idleTimeoutInterval, repeating: false) {
			if let reporter = InstrumentationSystem.reporter {
				reporter.idleTimeout()
			}
		}
	}

	// MARK: Public

	/// Controls when to set `traceparent` header on HTTP spans
	public enum TraceParentMode {
		/// Never set
		case never

		/// Only if sampling is enabled
		case ifSampling

		/// Always -- flag indicates sampling state
		case always
	}

	public static let defaultFlushInterval: TimeInterval = 60
	public static let defaultIdleInterval: TimeInterval = 10

	/// Convenience to track the expected state of sampling
	/// Traceparent headers use this by default
	public var isSampling = false

	/// Controls when to set `traceparent` header on HTTP spans
	public var traceParentMode = TraceParentMode.always

	/// Fetch the current span, using task local or thread local values, falling back to the root span.
	public var currentSpan: Span {
		currentBaggage.span
	}

	public var root: Span {
		lock.withLock {
			if let root = _root {
				return root
			} else {
				let root = Span(name: "root", traceId: traceId, parentId: nil, retireCallback: retire, isRoot: true)
				_root = root
				return root
			}
		}
	}

	/// Flushes the root span, and cycles the trace id
	public func flushTrace() {
		idleTimer?.suspend()

		let priorRoot = lock.withLock {
			let priorRoot = _root
			traceId = Identifiers.generateTraceId()
			_root = nil // will be recreated on next access
			return priorRoot
		}

		priorRoot?.end() // this implicitly retires if there is a current root
		flushRetiredSpans()
	}

	/// Creates a new subtrace span, with a link to a parent span.
	/// Subtraces allow creating a tree of traces, making visualization easier.
	/// Each subtrace should ideally represent a logical sub-area, or user activity.
	/// - Parameters:
	///   - name: The name of the new span.
	///   - kind: the kind of the span - may be left unspecified, but should be set to `.client` for network calls.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: A new span with a detached trace.
	public func startSubtraceSpan(
		name: String,
		kind: SpanKind = .unspecified,
		attributes: TelemetryAttributes? = nil,
		baggage: Baggage? = nil,
	) -> Span {
		let resolvedBaggage = baggage ?? currentBaggage
		let subTraceBaggage = Baggage(
			span: resolvedBaggage.span,
			subTraceId: Identifiers.generateTraceId(),
			subtraceLinking: resolvedBaggage.subtraceLinking,
			attributes: resolvedBaggage.attributes
		)
		return startSpan(name: name, kind: kind, attributes: attributes, baggage: subTraceBaggage)
	}

	/// Create a new subtrace span that measures a specific block of code, with a link to a parent span.
	/// - Parameters:
	///   - name: The name of the new span.
	///   - kind: the kind of the span - may be left unspecified, but should be set to `.client` for network calls.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: A new span with a detached trace.
	public func withSubtraceSpan<T>(
		name: String,
		kind: SpanKind = .unspecified,
		attributes: TelemetryAttributes? = nil,
		baggage: Baggage? = nil,
		block: () throws -> T,
	) rethrows -> T {
		let resolvedBaggage = baggage ?? currentBaggage
		let subTraceBaggage = Baggage(
			span: resolvedBaggage.span,
			subTraceId: Identifiers.generateTraceId(),
			subtraceLinking: resolvedBaggage.subtraceLinking,
			attributes: resolvedBaggage.attributes
		)
		return try withSpan(name: name, kind: kind, attributes: attributes, baggage: subTraceBaggage, block: block)
	}

	/// Create a manually managed span.
	/// - Parameters:
	///   - name: the name of the operation.
	///   - kind: the kind of the span - may be left unspecified, but should be set to `.client` for network calls.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: A newly created span.
	public func startSpan(
		name: String,
		kind: SpanKind = .unspecified,
		attributes: TelemetryAttributes? = nil,
		baggage: Baggage? = nil,
	) -> Span {
		buildSpan(name: name, kind: kind, attributes: attributes, baggage: baggage)
	}

	/// Propagate a parent span into the enclosed block via TaskLocal.
	/// Preferred to use `propagateBaggage`, as it introduces fewer stack frames.
	/// - Parameters:
	///   - span: The parent span.
	///   - block: The code to execute.
	/// - Returns: The return value of the closure.
	public func propagateParent<T>(_ span: Span, block: () throws -> T) rethrows -> T {
		let baggage = Baggage(span: span)
		return try propagateBaggage(baggage, block: block)
	}

	/// Propagate baggage into the enclosed block via TaskLocal.
	/// - Parameters:
	///   - baggage: The baggage to propagate.
	///   - block: The code to execute.
	/// - Returns: The return value of the closure.
	public func propagateBaggage<T>(_ baggage: Baggage, block: () throws -> T) rethrows -> T {
		do {
			return try Baggage.$currentBaggageTaskLocal.withValue(baggage) {
				try block()
			}
		} catch {
			baggage.span.recordError(error)
			throw error // rethrow
		}
	}

	/// Create a span that measures a specific block of code.
	/// - Parameters:
	///   - name: the name of the operation.
	///   - kind: the kind of the span - may be safely left unspecified in most cases.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: the result of the wrapped code.
	public func withSpan<T>(
		name: String,
		kind: SpanKind = .unspecified,
		attributes: TelemetryAttributes? = nil,
		baggage: Baggage? = nil,
		block: () throws -> T,
	) rethrows -> T {
		let span = buildSpan(name: name, kind: kind, attributes: attributes, baggage: baggage)

		defer {
			span.end() // automatically retires the span
		}

		// Carry forward any previous baggage attributes
		let newBaggage = Baggage(span: span, attributes: baggage?.attributes)
		return try Baggage.$currentBaggageTaskLocal.withValue(newBaggage) {
			do {
				return try block()
			} catch {
				span.recordError(error)
				throw error // rethrow
			}
		}
	}

	/// Create a span that measures a specific async block.
	/// - Parameters:
	///   - name: the name of the span.
	///   - kind: the kind of the span - may be safely left unspecified in most cases.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: the result of the wrapped code.
	public func withSpan<T>(
		name: String,
		kind: SpanKind = .unspecified,
		attributes: TelemetryAttributes? = nil,
		baggage: Baggage? = nil,
		block: () async throws -> T,
	) async rethrows -> T {
		let span = buildSpan(name: name, kind: kind, attributes: attributes, baggage: baggage)

		defer {
			span.end() // automatically retires the span
		}

		// Carry forward any previous baggage attributes
		let newBaggage = Baggage(span: span, attributes: baggage?.attributes)
		return try await Baggage.$currentBaggageTaskLocal.withValue(newBaggage) {
			do {
				return try await block()
			} catch {
				span.recordError(error)
				throw error // rethrow
			}
		}
	}

	// MARK: Internal

	let lock = OSAllocatedUnfairLock()

	var traceId = Identifiers.generateTraceId()
	var retiredSpans = [Span]()

	/// Optional to avoid initialization order issue
	var flushTimer: FlushTimer? = nil
	var idleTimer: FlushTimer? = nil

	var currentBaggage: Baggage {
		if let baggage = Baggage.currentBaggageTaskLocal {
			baggage
		} else {
			Baggage(span: root)
		}
	}

	/// Sets the flush interval for reporting back to the configured ``Reporter``.
	var flushInterval: TimeInterval {
		didSet {
			flushTimer?.flushInterval = flushInterval
		}
	}

	var idleTimeoutInterval: TimeInterval {
		didSet {
			idleTimer?.flushInterval = idleTimeoutInterval
		}
	}

	func retire(span: Span) {
		lock.withLock {
			retiredSpans.append(span)
		}

		// Push the timeout ahead
		idleTimer?.setupTimer()
	}

	func flushRetiredSpans() {
		let spansToReport: [Span] = lock.withLock {
			// copy and empty the array.
			let spans = retiredSpans
			retiredSpans.removeAll()
			return spans
		}

		// If we have no reporter, we'll drop them on the floor to avoid unbounded growth.
		if spansToReport.count > 0, let reporter = InstrumentationSystem.reporter {
			reporter.reportSpans(spansToReport)
		}
	}

	/// Internal function to build spans with correct parent association.
	/// - Parameters:
	///   - name: the name of the span.
	///   - kind: the kind of the span - may be safely left unspecified in most cases.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: An initialized span.
	func buildSpan(
		name: String,
		kind: SpanKind = .unspecified,
		attributes: TelemetryAttributes? = nil,
		baggage: Baggage? = nil,
	) -> Span {
		let resolvedBaggage = baggage ?? currentBaggage
		let finalKind = (kind == .unspecified) ? resolvedBaggage.span.kind : kind // infer from parent span if unspecified

		let mergedAttributes = mergeAttributes(baggageAttributes: resolvedBaggage.attributes, spanAttributes: attributes)

		if let subTraceId = resolvedBaggage.subTraceId {
			// Create a new detached trace with optional linking

			let result = Span(
				name: name,
				kind: finalKind,
				attributes: mergedAttributes,
				traceId: subTraceId,
				parentId: nil,
				retireCallback: retire,
			)

			let parent = resolvedBaggage.span

			if resolvedBaggage.subtraceLinking.contains(.up) {
				result.addLink(parent, relationship: .parent)
			}
			if resolvedBaggage.subtraceLinking.contains(.down) {
				parent.addLink(result, relationship: .child)
			}

			return result
		} else {
			return Span(
				name: name,
				kind: finalKind,
				attributes: mergedAttributes,
				traceId: resolvedBaggage.span.traceId,
				parentId: resolvedBaggage.span.id,
				retireCallback: retire,
			)
		}
	}

	/// Produces the merged dictionary of baggage and span attributes, or nil when both are nil.
	/// Span attributes are preferred
	/// - Parameters:
	///   - baggageAttributes: attributes from baggage
	///   - spanAttributes: any attributes from the span
	/// - Returns: The merged attribute dictionary
	func mergeAttributes(baggageAttributes: TelemetryAttributes?, spanAttributes: TelemetryAttributes?) -> TelemetryAttributes? {
		guard let baggageAttributes else { return spanAttributes }
		guard let spanAttributes else { return baggageAttributes }
		return baggageAttributes.merging(spanAttributes) { _, new in new }
	}

	// MARK: Private

	/// Must be accessed with lock
	private var _root: Span?

}
