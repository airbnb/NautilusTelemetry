//
//  SpanTests.swift
//
//
//  Created by Van Tol, Ladd on 9/27/21.
//

import Foundation
import Testing

@testable import NautilusTelemetry

@Suite
struct SpanTests {

	enum TestError: Error {
		case failure
	}

	let tracer = Tracer()
	let iterations = 100

	let traceParentValueRegex_Sampling = /00-[a-f0-9]{32}-[a-f0-9]{16}-01/
	let traceParentValueRegex_NotSampling = /00-[a-f0-9]{32}-[a-f0-9]{16}-00/

	@Test
	func traceId() {
		let traceId = Identifiers.generateTraceId()
		#expect(traceId.count == 16)
		#expect(traceId != Data(repeating: 0, count: 16))

		let serial = DispatchQueue(label: "serial")
		var set = Set<Data>()

		DispatchQueue.concurrentPerform(iterations: iterations) { _ in
			let traceId = Identifiers.generateTraceId()
			_ = serial.sync { set.insert(traceId) }
		}

		#expect(set.count == iterations)
	}

	@Test
	func spanId() {
		let spanId = Identifiers.generateSpanId()
		#expect(spanId.count == 8)
		#expect(spanId != Data(repeating: 0, count: 8))

		let serial = DispatchQueue(label: "serial")
		var set = Set<Data>()

		DispatchQueue.concurrentPerform(iterations: iterations) { _ in
			let traceId = Identifiers.generateSpanId()
			_ = serial.sync { set.insert(traceId) }
		}

		#expect(set.count == iterations)
	}

	@Test
	func trace() throws {
		try tracer.withSpan(name: "span1") {
			#expect(tracer.currentBaggage.span.parentId != nil)
			try span2Run()
			tracer.currentSpan.addEvent(Span.Event(name: "event1"))
		}

		#expect(tracer.retiredSpans.count == 2)

		let span2 = tracer.retiredSpans[0]
		#expect(span2.events?.count == 2)
		#expect(span2.status == .ok)

		let traceParentHeader = span2.traceParentHeaderValue(sampled: true)
		#expect(traceParentHeader.0 == "traceparent")
		#expect(try traceParentValueRegex_Sampling.wholeMatch(in: traceParentHeader.1) != nil)
	}

	@Test
	func traceWithError() throws {
		try tracer.withSpan(name: "span1") {
			#expect(tracer.currentBaggage.span.parentId != nil)
			try span2Run()
			tracer.currentSpan.recordError(TestError.failure, includeBacktrace: true)
			tracer.currentSpan.addEvent(Span.Event(name: "event1"))
		}

		#expect(tracer.retiredSpans.count == 2)

		let span2 = tracer.retiredSpans[0]
		#expect(span2.events?.count == 2)
		#expect(span2.status == .ok)

		let span1 = tracer.retiredSpans[1]
		#expect(span1.status == .error(message: "failure"))

		let exceptionType = try #require(span1.events?[0].attributes?["exception.type"]?.stringPayload)
		#expect(exceptionType == "NautilusTelemetryTests.SpanTests.TestError")

		let event = span1.events?[0]
		let backtrace = try #require(event?.attributes?["exception.stacktrace"]?.stringPayload)
		#expect(backtrace.contains("traceWithError"))

		let traceParentHeader = span2.traceParentHeaderValue(sampled: false)
		#expect(traceParentHeader.0 == "traceparent")
		#expect(try traceParentValueRegex_NotSampling.wholeMatch(in: traceParentHeader.1) != nil)
	}

	@Test
	func traceparentHeader() throws {
		let url = try TestUtils.makeURL("https://api.example.com/")
		let span = tracer.startSpan(name: "test")

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersIfSampling(&urlRequest, isSampling: true)
			let header = try #require(urlRequest.value(forHTTPHeaderField: "traceparent"))
			#expect(try traceParentValueRegex_Sampling.wholeMatch(in: header) != nil)
		}

		do {
			var urlRequest = URLRequest(url: url)
			let span = tracer.startSpan(name: "test")
			span.addTraceHeadersIfSampling(&urlRequest, isSampling: false)
			#expect(urlRequest.value(forHTTPHeaderField: "traceparent") == nil)
		}

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersUnconditionally(&urlRequest, isSampling: true)
			let header = try #require(urlRequest.value(forHTTPHeaderField: "traceparent"))
			#expect(try traceParentValueRegex_Sampling.wholeMatch(in: header) != nil)
		}

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersUnconditionally(&urlRequest, isSampling: false)
			let header = try #require(urlRequest.value(forHTTPHeaderField: "traceparent"))
			#expect(try traceParentValueRegex_NotSampling.wholeMatch(in: header) != nil)
		}
	}

	@Test
	func throwingSpan() throws {
		#expect(throws: TestError.self) {
			try tracer.withSpan(name: "span1") {
				throw TestError.failure
			}
		}

		#expect(tracer.retiredSpans.count == 1)

		let span1 = tracer.retiredSpans[0]
		#expect(span1.status != .ok)
	}

	@Test
	func asyncSpan() async throws {
		// Verifies the async `withSpan` overload: the block must perform a real
		// `await` so Swift resolves to the `async` variant (otherwise the call
		// would fall back to the synchronous overload and emit "no 'async'
		// operations occur within 'await' expression").
		try await tracer.withSpan(name: "span1") {
			#expect(tracer.currentBaggage.span.parentId != nil)
			try await asyncSpan2Run()
		}

		#expect(tracer.retiredSpans.count == 2)

		let span2 = tracer.retiredSpans[0]
		#expect(span2.events?.count == 2)
		#expect(span2.status == .ok)
	}

	func span2Run() throws {
		var ranSpan = false
		tracer.withSpan(name: "span2") {
			let span = tracer.currentBaggage.span
			span.addEvent("event1")
			Thread.sleep(forTimeInterval: 0.1)
			span.addEvent("event2")
			span.status = .ok
			ranSpan = true
		}
		#expect(ranSpan)
	}

	func asyncSpan2Run() async throws {
		var ranSpan = false
		try await tracer.withSpan(name: "span2") {
			let span = tracer.currentBaggage.span
			span.addEvent("event1")
			// `Task.sleep` is a genuine suspension point, unlike `Thread.sleep`,
			// so this block actually exercises the `async` `withSpan` overload.
			try await Task.sleep(for: .milliseconds(100))
			span.addEvent("event2")
			span.status = .ok
			ranSpan = true
		}
		#expect(ranSpan)
	}

	@Test
	func memoryLeaks() {
		weak var weakSpan1: Span?
		weak var weakSpan2: Span?

		autoreleasepool {
			let span1 = tracer.startSpan(name: "span1")
			weakSpan1 = span1

			tracer.withSpan(name: "span2") {
				let span2 = tracer.currentBaggage.span
				weakSpan2 = span2
				span2.addEvent("event1")
				Thread.sleep(forTimeInterval: 0.1)
				span2.addEvent("event2")
				span2.status = .ok
			}

			tracer.flushRetiredSpans()
		}

		#expect(weakSpan1 == nil)
		#expect(weakSpan2 == nil)
	}

	@Test
	func recordNSError() throws {
		let span = tracer.startSpan(name: "errorSpan")
		let error = NSError(domain: "VeryBadError", code: -42, userInfo: [NSLocalizedDescriptionKey: "NSFailed"])
		span.recordError(error)

		let exceptionEvent = try #require(span.events?.first)
		let exceptionAttributes = try #require(exceptionEvent.attributes)
		#expect(span.status == .error(message: "NSFailed"))
		#expect(exceptionAttributes["exception.type"]?.stringPayload == "NSError.VeryBadError.-42")
		#expect(exceptionAttributes["exception.message"]?.stringPayload == "NSFailed")
	}

	@Test
	func recordError() throws {
		let error = TestError.failure
		let span = tracer.startSpan(name: "errorSpan")
		span.recordError(error)

		let exceptionEvent = try #require(span.events?.first)
		let exceptionAttributes = try #require(exceptionEvent.attributes)
		#expect(span.status == .error(message: "failure"))
		#expect(exceptionAttributes["exception.type"]?.stringPayload == "NautilusTelemetryTests.SpanTests.TestError")
		#expect(exceptionAttributes["exception.message"]?.stringPayload == "failure")
	}

	@Test
	func recordErrorWithMessage() throws {
		let span = tracer.startSpan(name: "errorSpan")
		span.recordError(withType: "custom", message: "custom error message")

		let exceptionEvent = try #require(span.events?.first)
		let exceptionAttributes = try #require(exceptionEvent.attributes)
		#expect(span.status == .error(message: "custom error message"))
		#expect(exceptionAttributes["exception.type"]?.stringPayload == "custom")
		#expect(exceptionAttributes["exception.message"]?.stringPayload == "custom error message")
	}

	@Test
	func concurrentAddLinks() {
		let span = tracer.startSpan(name: "concurrentAddLinks")

		DispatchQueue.concurrentPerform(iterations: 100) { _ in
			let child = tracer.startSpan(name: "concurrentAddLinks")
			span.addLink(child, relationship: .child)
		}
	}

	@Test
	func spanIsRootDefaultValue() {
		let traceId = Identifiers.generateTraceId()
		let span = Span(name: "test", kind: .internal, traceId: traceId, parentId: nil)
		#expect(span.isRoot == false)
	}

	@Test
	func spanIsRootExplicitlySetToTrue() {
		let traceId = Identifiers.generateTraceId()
		let span = Span(name: "test", kind: .internal, traceId: traceId, parentId: nil, isRoot: true)
		#expect(span.isRoot == true)
	}

	@Test
	func spanIsRootExplicitlySetToFalse() {
		let traceId = Identifiers.generateTraceId()
		let span = Span(name: "test", kind: .internal, traceId: traceId, parentId: nil, isRoot: false)
		#expect(span.isRoot == false)
	}

	@Test
	func nonRootSpanHasIsRootFalse() {
		let traceId = Identifiers.generateTraceId()
		let parentId = Identifiers.generateSpanId()
		let span = Span(name: "child", kind: .internal, traceId: traceId, parentId: parentId)
		#expect(span.isRoot == false)
	}

	@Test
	func overlapsInterval() {
		let traceId = Identifiers.generateTraceId()
		let t = ContinuousClock.now

		func makeSpan(start: Duration, end: Duration) -> Span {
			Span(name: "test", startTime: t + start, endTime: t + end, traceId: traceId, parentId: nil)
		}

		let span = makeSpan(start: .seconds(2), end: .seconds(4))

		// Overlapping cases
		#expect(span.overlapsInterval(t + .seconds(1), t + .seconds(5)), "interval encompasses span")
		#expect(span.overlapsInterval(t + .seconds(3), t + .seconds(3)), "span encompasses interval")
		#expect(span.overlapsInterval(t + .seconds(1), t + .seconds(3)), "overlap at start")
		#expect(span.overlapsInterval(t + .seconds(3), t + .seconds(5)), "overlap at end")
		#expect(span.overlapsInterval(t + .seconds(2), t + .seconds(4)), "exact match")
		#expect(span.overlapsInterval(t + .seconds(4), t + .seconds(5)), "shared endpoint")

		// Non-overlapping cases
		#expect(!span.overlapsInterval(t + .seconds(0), t + .seconds(1)), "entirely before")
		#expect(!span.overlapsInterval(t + .seconds(5), t + .seconds(6)), "entirely after")
	}

	@Test
	func spanSubscript() {
		let span = tracer.startSpan(name: "test")
		span["key1"] = "value1"
		#expect(span["key1"] == "value1")
	}

	@Test
	func sampleRate() {
		let traceId = Identifiers.generateTraceId()
		#expect(Span(name: "test", traceId: traceId, parentId: nil).sampleRate == nil)
		#expect(Span(name: "test", traceId: traceId, parentId: nil, sampleRate: 50.0).sampleRate == 50.0)
	}

	@Test
	func adjust() {
		let traceId = Identifiers.generateTraceId()
		let t = ContinuousClock.now

		// start only
		let span1 = Span(name: "test", startTime: t, endTime: t + .seconds(10), traceId: traceId, parentId: nil)
		span1.adjust(start: .seconds(2))
		#expect(span1.startTime == t + .seconds(2))
		#expect(span1.endTime == t + .seconds(10))

		// end only
		let span2 = Span(name: "test", startTime: t, endTime: t + .seconds(10), traceId: traceId, parentId: nil)
		span2.adjust(end: .seconds(3))
		#expect(span2.startTime == t)
		#expect(span2.endTime == t + .seconds(13))

		// both start and end
		let span3 = Span(name: "test", startTime: t, endTime: t + .seconds(10), traceId: traceId, parentId: nil)
		span3.adjust(start: .seconds(-1), end: .seconds(-2))
		#expect(span3.startTime == t - .seconds(1))
		#expect(span3.endTime == t + .seconds(8))

		// nil endTime is unaffected
		let span4 = Span(name: "test", startTime: t, traceId: traceId, parentId: nil)
		span4.adjust(start: .seconds(5), end: .seconds(5))
		#expect(span4.startTime == t + .seconds(5))
		#expect(span4.endTime == nil)
	}
}
