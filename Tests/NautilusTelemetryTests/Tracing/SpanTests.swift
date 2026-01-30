//
//  SpanTests.swift
//
//
//  Created by Van Tol, Ladd on 9/27/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class SpanTests: XCTestCase {

	enum TestError: Error {
		case failure
	}

	let tracer = Tracer()

	let iterations = 100

	let traceParentValueRegex_Sampling = /00-[a-f0-9]{32}-[a-f0-9]{16}-01/
	let traceParentValueRegex_NotSampling = /00-[a-f0-9]{32}-[a-f0-9]{16}-00/

	override func tearDown() {
		tracer.flushRetiredSpans()
	}

	func testTraceId() {
		let traceId = Identifiers.generateTraceId()
		XCTAssertEqual(traceId.count, 16)
		XCTAssertNotEqual(traceId, Data(repeating: 0, count: 16))

		let serial = DispatchQueue(label: "serial")
		var set = Set<Data>()

		DispatchQueue.concurrentPerform(iterations: iterations) { _ in
			let traceId = Identifiers.generateTraceId()
			_ = serial.sync { set.insert(traceId) }
		}

		XCTAssert(set.count == iterations) // check for duplicates
	}

	func testSpanId() {
		let spanId = Identifiers.generateSpanId()
		XCTAssertEqual(spanId.count, 8)
		XCTAssertNotEqual(spanId, Data(repeating: 0, count: 8))

		let serial = DispatchQueue(label: "serial")
		var set = Set<Data>()

		DispatchQueue.concurrentPerform(iterations: iterations) { _ in
			let traceId = Identifiers.generateSpanId()
			_ = serial.sync { set.insert(traceId) }
		}

		XCTAssert(set.count == iterations) // check for duplicates
	}

	func testTrace() throws {
		// we expect this test to run on main queue
		dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

		try tracer.withSpan(name: "span1") {
			XCTAssert(tracer.currentBaggage.span.parentId != nil)
			try span2Run()
			tracer.currentSpan.addEvent(Span.Event(name: "event1"))
		}

		XCTAssert(tracer.retiredSpans.count == 2)

		let span2 = tracer.retiredSpans[0]
		XCTAssert(span2.events?.count == 2)
		XCTAssert(span2.status == .ok)

		let traceParentHeader = span2.traceParentHeaderValue(sampled: true)
		XCTAssertEqual(traceParentHeader.0, "traceparent")

		XCTAssert(try traceParentValueRegex_Sampling.wholeMatch(in: traceParentHeader.1) != nil)
	}

	func testTraceWithError() throws {
		// we expect this test to run on main queue
		dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

		try tracer.withSpan(name: "span1") {
			XCTAssert(tracer.currentBaggage.span.parentId != nil)
			try span2Run()
			tracer.currentSpan.recordError(TestError.failure, includeBacktrace: true)
			tracer.currentSpan.addEvent(Span.Event(name: "event1"))
		}

		XCTAssert(tracer.retiredSpans.count == 2)

		let span2 = tracer.retiredSpans[0]
		XCTAssert(span2.events?.count == 2)
		XCTAssert(span2.status == .ok)

		let span1 = tracer.retiredSpans[1]
		XCTAssertEqual(
			span1.status,
			.error(message: "failure")
		)

		let exceptionType = try XCTUnwrap(span1.events?[0].attributes?["exception.type"])
		XCTAssertEqual(exceptionType, "NautilusTelemetryTests.SpanTests.TestError")

		let event = span1.events?[0]
		let backtrace = try XCTUnwrap(event?.attributes?["exception.stacktrace"] as? String)

		XCTAssert(backtrace.contains("testTraceWithError"))

		let traceParentHeader = span2.traceParentHeaderValue(sampled: false)
		XCTAssertEqual(traceParentHeader.0, "traceparent")
		XCTAssert(try traceParentValueRegex_NotSampling.wholeMatch(in: traceParentHeader.1) != nil)
	}

	func testTraceparentHeader() throws {
		let url = try makeURL("https://api.example.com/")
		let span = tracer.startSpan(name: "test")

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersIfSampling(&urlRequest, isSampling: true)
			let header = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "traceparent"))
			XCTAssert(try traceParentValueRegex_Sampling.wholeMatch(in: header) != nil)
		}

		do {
			var urlRequest = URLRequest(url: url)
			let span = tracer.startSpan(name: "test")
			span.addTraceHeadersIfSampling(&urlRequest, isSampling: false)
			XCTAssertNil(urlRequest.value(forHTTPHeaderField: "traceparent"))
		}

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersUnconditionally(&urlRequest, isSampling: true)
			let header = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "traceparent"))
			XCTAssert(try traceParentValueRegex_Sampling.wholeMatch(in: header) != nil)
		}

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersUnconditionally(&urlRequest, isSampling: false)
			let header = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "traceparent"))
			XCTAssert(try traceParentValueRegex_NotSampling.wholeMatch(in: header) != nil)
		}
	}

	func testThrowing() throws {
		// we expect this test to run on main queue
		dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

		do {
			try tracer.withSpan(name: "span1") {
				throw TestError.failure
			}
		} catch { }

		XCTAssert(tracer.retiredSpans.count == 1)

		let span1 = tracer.retiredSpans[0]
		XCTAssert(span1.status != .ok)
	}

	#if compiler(>=5.6.0) && canImport(_Concurrency)
	func testAsync() async throws {
		try await tracer.withSpan(name: "span1") {
			XCTAssert(tracer.currentBaggage.span.parentId != nil)
			try await span2RunAsync()
		}

		XCTAssert(tracer.retiredSpans.count == 2)

		let span2 = tracer.retiredSpans[0]
		XCTAssert(span2.events?.count == 2)
		XCTAssert(span2.status == .ok)
	}
	#endif

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

		XCTAssert(ranSpan)
	}

	func span2RunAsync() async throws {
		var ranSpan = false
		tracer.withSpan(name: "span2async") {
			let span = tracer.currentBaggage.span
			span.addEvent("event1")
			Thread.sleep(forTimeInterval: 0.1)
			span.addEvent("event2")
			span.status = .ok
			ranSpan = true
		}

		XCTAssert(ranSpan)
	}

	func testForMemoryLeaks() throws {
		let span1 = tracer.startSpan(name: "span1")
		trackForMemoryLeak(instance: span1)

		tracer.withSpan(name: "span2") {
			let span2 = tracer.currentBaggage.span
			span2.addEvent("event1")
			Thread.sleep(forTimeInterval: 0.1)
			span2.addEvent("event2")
			span2.status = .ok

			trackForMemoryLeak(instance: span2)
		}

		tracer.flushRetiredSpans() // make sure retired spans don't show up as leaks
	}

	func test_recordNSError() throws {
		let span = tracer.startSpan(name: "errorSpan")
		let error = NSError(domain: "VeryBadError", code: -42, userInfo: [NSLocalizedDescriptionKey: "NSFailed"])
		span.recordError(error)

		let exceptionEvent = try XCTUnwrap(span.events?.first)
		let exceptionAttributes = try XCTUnwrap(exceptionEvent.attributes)
		XCTAssertEqual(span.status, .error(message: "NSFailed"))
		XCTAssertEqual(exceptionAttributes["exception.type"], "NSError.VeryBadError.-42")
		XCTAssertEqual(exceptionAttributes["exception.message"], "NSFailed")
	}

	func test_recordError() throws {
		let error = TestError.failure
		let span = tracer.startSpan(name: "errorSpan")
		span.recordError(error)

		let exceptionEvent = try XCTUnwrap(span.events?.first)
		let exceptionAttributes = try XCTUnwrap(exceptionEvent.attributes)
		XCTAssertEqual(span.status, .error(message: "failure"))
		XCTAssertEqual(exceptionAttributes["exception.type"], "NautilusTelemetryTests.SpanTests.TestError")
		XCTAssertEqual(exceptionAttributes["exception.message"], "failure")
	}

	func test_recordErrorWithMessage() throws {
		let span = tracer.startSpan(name: "errorSpan")
		span.recordError(withType: "custom", message: "custom error message")

		let exceptionEvent = try XCTUnwrap(span.events?.first)
		let exceptionAttributes = try XCTUnwrap(exceptionEvent.attributes)
		XCTAssertEqual(span.status, .error(message: "custom error message"))
		XCTAssertEqual(exceptionAttributes["exception.type"], "custom")
		XCTAssertEqual(exceptionAttributes["exception.message"], "custom error message")
	}

	func test_concurrentAddLinks() throws {
		let span = tracer.startSpan(name: "concurrentAddLinks")

		DispatchQueue.concurrentPerform(iterations: 100) { _ in
			let child = tracer.startSpan(name: "concurrentAddLinks")
			span.addLink(child, relationship: .child)
		}
	}

	func testSpanIsRootDefaultValue() {
		let traceId = Identifiers.generateTraceId()
		let span = Span(name: "test", kind: .internal, traceId: traceId, parentId: nil)

		XCTAssertFalse(span.isRoot)
	}

	func testSpanIsRootExplicitlySetToTrue() {
		let traceId = Identifiers.generateTraceId()
		let span = Span(name: "test", kind: .internal, traceId: traceId, parentId: nil, isRoot: true)

		XCTAssertTrue(span.isRoot)
	}

	func testSpanIsRootExplicitlySetToFalse() {
		let traceId = Identifiers.generateTraceId()
		let span = Span(name: "test", kind: .internal, traceId: traceId, parentId: nil, isRoot: false)

		XCTAssertFalse(span.isRoot)
	}

	func testNonRootSpanHasIsRootFalse() {
		let traceId = Identifiers.generateTraceId()
		let parentId = Identifiers.generateSpanId()
		let span = Span(name: "child", kind: .internal, traceId: traceId, parentId: parentId)

		XCTAssertFalse(span.isRoot)
	}

	func testSpanSubscript() {
		let span = tracer.startSpan(name: "test")
		span["key1"] = "value1"
		XCTAssertEqual(span["key1"], "value1")
	}
}
