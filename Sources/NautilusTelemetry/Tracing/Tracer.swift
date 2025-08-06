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
		root = Span(name: "root", kind: .internal, traceId: traceId, parentId: nil)
		flushInterval = 60
		root.retireCallback = retire // initialization order
	}

	// MARK: Public

	/// Convenience to track the expected state of sampling
	/// Traceparent headers use this by default
	public var isSampling = false

	/// Fetch the current span, using task local or thread local values, falling back to the root span.
	public var currentSpan: Span { currentBaggage.span }

	/// Flushes the root span, and cycles the trace id
	public func flushTrace() {
		root.end() // this implicitly retires

		Tracer.lock.withLock {
			traceId = Identifiers.generateTraceId()
			root = Span(name: "root", traceId: traceId, parentId: nil, retireCallback: retire)
		}

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
		baggage: Baggage? = nil
	) -> Span {
		let resolvedBaggage = baggage ?? currentBaggage
		let subTraceBaggage = Baggage(
			span: resolvedBaggage.span,
			subTraceId: Identifiers.generateTraceId(),
			subtraceLinking: resolvedBaggage.subtraceLinking
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
		block: () throws -> T
	) rethrows -> T {
		let resolvedBaggage = baggage ?? currentBaggage
		let subTraceBaggage = Baggage(
			span: resolvedBaggage.span,
			subTraceId: Identifiers.generateTraceId(),
			subtraceLinking: resolvedBaggage.subtraceLinking
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
		baggage: Baggage? = nil
	) -> Span {
		buildSpan(name: name, kind: kind, attributes: attributes, baggage: baggage)
	}

	/// Propagate a parent span into the enclosed block via TaskLocal.
	/// - Parameters:
	///   - span: The parent span.
	///   - block: The code to execute.
	/// - Returns: The return value of the closure.
	public func propagateParent<T>(_ span: Span, block: () throws -> T) rethrows -> T {
		let baggage = Baggage(span: span)
		return try Baggage.$currentBaggageTaskLocal.withValue(baggage) {
			do {
				return try block()
			} catch {
				span.recordError(error)
				throw error // rethrow
			}
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
		block: () throws -> T
	) rethrows -> T {
		let span = buildSpan(name: name, kind: kind, attributes: attributes, baggage: baggage)

		defer {
			span.end() // automatically retires the span
		}

		return try Baggage.$currentBaggageTaskLocal.withValue(Baggage(span: span)) {
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
		block: () async throws -> T
	) async rethrows -> T {
		let span = buildSpan(name: name, kind: kind, attributes: attributes, baggage: baggage)

		defer {
			span.end() // automatically retires the span
		}

		return try await Baggage.$currentBaggageTaskLocal.withValue(Baggage(span: span)) {
			do {
				return try await block()
			} catch {
				span.recordError(error)
				throw error // rethrow
			}
		}
	}

	// MARK: Internal

	static let lock = OSAllocatedUnfairLock()

	var traceId = Identifiers.generateTraceId()
	var root: Span
	var retiredSpans = [Span]()
	var flushTimer: DispatchSourceTimer? = nil

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
			if let flushTimer {
				flushTimer.cancel()
				self.flushTimer = nil
			}

			flushTimer = DispatchSource.makeTimerSource(flags: [], queue: NautilusTelemetry.queue)

			if let flushTimer {
				flushTimer.setEventHandler(handler: { [weak self] in self?.flushRetiredSpans() })
				flushTimer.schedule(
					deadline: DispatchTime.now() + flushInterval,
					repeating: flushInterval,
					leeway: DispatchTimeInterval.milliseconds(100)
				)
				flushTimer.activate()
			}
		}
	}

	func retire(span: Span) {
		Tracer.lock.withLock {
			retiredSpans.append(span)
		}
	}

	func flushRetiredSpans() {
		let spansToReport: [Span] = Tracer.lock.withLock {
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
		baggage: Baggage? = nil
	) -> Span {
		let resolvedBaggage = baggage ?? currentBaggage
		let finalKind = (kind == .unspecified) ? resolvedBaggage.span.kind : kind // infer from parent span if unspecified

		if let subTraceId = resolvedBaggage.subTraceId {
			// Create a new detached trace with optional linking

			let result = Span(
				name: name,
				kind: finalKind,
				attributes: attributes,
				traceId: subTraceId,
				parentId: nil,
				retireCallback: retire
			)

			let parent = resolvedBaggage.span

			switch resolvedBaggage.subtraceLinking {
			case .none:
				break // no link needed
			case .up:
				result.addLink(parent, relationship: .parent)
			case .down:
				parent.addLink(result, relationship: .child)
			case .bidirectional:
				result.addLink(parent, relationship: .parent)
				parent.addLink(result, relationship: .child)
			}

			return result
		} else {
			return Span(
				name: name,
				kind: finalKind,
				attributes: attributes,
				traceId: resolvedBaggage.span.traceId,
				parentId: resolvedBaggage.span.id,
				retireCallback: retire
			)
		}
	}
}
